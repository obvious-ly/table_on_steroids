# frozen_string_literal: true

#####
# The knowledge sharing concern permits creates a fast way to display,
# filter and order data of a specific object.
# To make it work:
# In the Object controller, include TableOnSteroid and add this private methods:

#   - columns_on_steroid: a Hash defining the columns and filters:
#      {
#        'key_defining_column_1' => {
#          label: 'Label 1',                         >>  the column label
#          type: 'filter',                           >> can be 'filter', 'order' or nothing if no operations
#          multiselect: true,                        >> OPTIONAL in case of a filter
#          select_values: ['Option 1','Option 2'],   >> in case of a filter, the options to select
#          filter_lambda: -> (objects, value) { .. } >> A lambda defining the filter if applicable
#          order_lambda: -> (objects) { .. },        >> A lambda defining the order if applicable
#          value_lambda: -> (object) { .. }          >> A lambda defining the value in the table
#        },
#        'key_defining_column_2' => {
#           ...
#        },
#        ...
#     }                                             >> See example in offers2_controller
#
# Add a deep_search function in your object
# Don't forget to add your route
# Create your view and add `= render partial: 'shared/table_on_steroid', locals: { objects: @offers }` to display the table
#
#####
require 'kaminari'
require 'csv'

module TableOnSteroids
  module TableConcern
    extend ActiveSupport::Concern

    included do
      OBJECTS_PER_PAGE = 50
    end

    def filter_and_order(objects, columns_on_steroid, global_search = nil, include_counts = false, all_pages = false, table_on_steroids = nil, rows_to_display = nil)

      limit = rows_to_display || OBJECTS_PER_PAGE

      # execute the global search if you have one
      if params[:search].present?
        objects = global_search.call(objects, params[:search]) if global_search
        objects = all_column_search(objects, columns_on_steroid, params[:search], table_on_steroids) unless global_search
      end

      %i[activerecord array].each do |t|
        # column search
        objects = objects_where(objects, columns_on_steroid, t)

        filter_columns = columns_on_steroid.map{|k,v| k if v.dig(t,:filter_lambda) }.compact
        filter_columns.each do |k|
          filter_value = (params[:filters] && params[:filters][k]) || params[k]
          if(!filter_value.blank?)
            objects = columns_on_steroid[k][t][:filter_lambda].call(objects, filter_value)
          end
        end

        #order
        if params&.dig(:knowledge,:order) && (object_order = columns_on_steroid[params[:knowledge][:order]]).present?
          if(object_order[t] && object_order[t][:order_lambda])
            direction = (params&.dig(:knowledge,:ascending).to_s == 'true') ? 'asc' : 'desc'
            objects = objects.reorder(nil) if(objects.is_a?(ActiveRecord::Base) || objects.is_a?(ActiveRecord::Relation))
            objects = object_order[t][:order_lambda].call(objects, direction)
          end
        elsif object_order = columns_on_steroid[table_on_steroids&.dig(:default_order_column)]
          if(object_order[t] && object_order[t][:order_lambda])
            direction = object_order[t][:default_order_direction] || 'asc'
            objects = objects.reorder(nil) if(objects.is_a?(ActiveRecord::Base) || objects.is_a?(ActiveRecord::Relation))
            objects = object_order[t][:order_lambda].call(objects, direction)
          end
        elsif (object_order = columns_on_steroid.select { |_c, v| v[t] && v[t][:default_order] }.first&.last).present?
          if object_order[t] && object_order[t][:order_lambda]
            objects = objects.reorder(nil) if objects.is_a?(ActiveRecord::Base) || objects.is_a?(ActiveRecord::Relation)
            objects = object_order[t][:order_lambda].call(objects)
          end
        elsif objects.is_a?(ActiveRecord::Base) || objects.is_a?(ActiveRecord::Relation)
          # objects = objects.order('created_at desc')
        end
      end

      # pagination
      return (include_counts ? [objects, 1, objects.count] : objects) if all_pages

      # GO to specific object page
      page = get_page(objects, params, table_on_steroids, limit)

      if objects.is_a?(ActiveRecord::Base) || objects.is_a?(ActiveRecord::Relation)
        objects = objects.page(page).per(limit)
        total_pages = objects.total_pages
        total_count = objects.total_count
      else
        objects = Kaminari.paginate_array(objects).page(page).per(limit)
        total_pages = objects.total_pages
        total_count = objects.total_count
      end
      include_counts ? [objects, total_pages, total_count, page] : objects
    end

    def table_csv(objects, columns_on_steroid)
      titles = []
      csvs = CSV.generate do |csv|
        columns_on_steroid.select { |_c, v| v[:download_value_lambda].present? }.each { |_c, v| (v[:download_label].present? ? titles.push(*v[:download_label]) : titles << v[:label]) }
        csv << titles
        objects.each do |o|
          vals = []
          columns_on_steroid.select { |_c, v| v[:download_value_lambda].present? }.each do |_c, v|
            vals.push(*v[:download_value_lambda].call(o))
          end
          csv << vals
        end
      end
    end

    def all_column_search(objects, columns_on_steroid, query, table_on_steroids = nil)
      global_active_record_search_key = table_on_steroids&.dig(:global_active_record_search_key) || :id
      global_array_search_key_index = table_on_steroids&.dig(:global_array_search_key_index) || 0
      global_search_key = (objects && objects[0].is_a?(Array) ? global_array_search_key_index : global_active_record_search_key)
      global_search_key_params = {}
      matched_object_keys = []

      %i[activerecord array].each do |t|
        columns_on_steroid.each do |_key, value|
          next unless value[t].present? && ((value[t][:search_lambda].present? && !%w[date integer].include?(value[:datatype])) || value[t][:global_search_lambda].present?)

          objects_returned = if value[t][:global_search_lambda].present?
                               value[t][:global_search_lambda].call(objects, query)
                             else
                               value[t][:search_lambda].call(objects, query)
                             end
          objects_returned&.each { |o| matched_object_keys << o[global_search_key] }
        end
      end

      if objects.is_a?(ActiveRecord::Base) || objects.is_a?(ActiveRecord::Relation)
        global_search_key_params[global_active_record_search_key] = matched_object_keys.uniq
        objects = objects.where(global_search_key_params)
      elsif objects.is_a?(Array)
        objects = objects.select { |o| o if matched_object_keys.uniq.include?(o[global_search_key]) }
      end
    end

    def objects_where(objects, columns_on_steroid, t)
      columns_on_steroid.select do |_c, v|
        v[t] && v[t][:search_lambda].present?
      end .each do |c, v|
        if params['search_operator_' + c] # (v[:datatype].present? && ['date','integer'].include?(v[:datatype]))
          objects = v[t][:search_lambda].call(objects, params['search_' + c], params['search_operator_' + c]) if params['search_' + c] && !params['search_' + c].blank?
        else
          objects = v[t][:search_lambda].call(objects, params['search_' + c]) if params['search_' + c] && !params['search_' + c].blank?
        end
      end
      objects
    end

    def objects_where_date(objects, column, value, operator)
      case operator
      when '<', '>='
        objects.where((column + ' ' + operator + ' ?'), (value + ' 00:00:00'))
      when '>', '<='
        objects.where((column + ' ' + operator + ' ?'), (value + ' 23:59:59'))
      when '='
        objects.where((column + ' between ? and ?'), (value + ' 00:00:00'), (value + ' 23:59:59'))
      end
    end

    def objects_where_ruby_date(object, column, value, operator)
      value = Date.strptime(value, '%m/%d/%Y').midnight
      case operator
      when '<'
        return object.send(column) < value
      when '>'
        return object.send(column) > value + 1.days - 1.seconds
      when '='
        return ((object.send(column) > value) && (object.send(column) < (value + 1.days - 1.seconds)))
      end
    end

    def object_where_integer(integer, operator, value)
      case operator
      when '<', '>='
        integer.to_f < value.to_f
      when '='
        integer.to_f == value.to_f
      when '>'
        integer.to_f > value.to_f
      end
    end

    # save for later
    def objects_where_or(objects, columns_on_steroid)
      where_sql = ''
      values = []

      # search all columns
      unless query.blank?
        where_sql += columns_on_steroid.select do |_c, v|
                       v[:or_where_sql].present?
                     end .map do |_c, v|
          v[:or_where_sql].map do |w|
            w[:where]
          end .join(' or ')
        end .join(' or ')

        columns_on_steroid.select do |_c, v|
          v[:or_where_sql].present?
        end .map do |_c, v|
          v[:or_where_sql].each do |w|
            values << (w[:value] || ('%' + query + '%'))
          end
        end

        where_sql = ('(' + where_sql + ')') unless where_sql.blank?

        objects = objects.where(where_sql, *values)
      end
      objects
    end

    def get_page(objects, params, table_on_steroids, limit)
      active_record_object_fetch_opts = table_on_steroids&.dig(:active_record_object_fetch_opts)
      key_lambda = table_on_steroids&.dig(:key_lambda)
      return params[:page] unless active_record_object_fetch_opts && key_lambda

      object = objects.where(active_record_object_fetch_opts).first
      return params[:page] unless object

      index = objects.index { |o| key_lambda.call(o) == key_lambda.call(object) }
      index ? index / limit + 1 : params[:page]
    end
  end
end
