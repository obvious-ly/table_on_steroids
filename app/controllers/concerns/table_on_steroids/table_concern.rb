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

module TableOnSteroids
  module TableConcern
    extend ActiveSupport::Concern

    included do
      OBJECTS_PER_PAGE = 50
    end
  
    def filter_and_order(objects, columns_on_steroid, global_search=nil, include_counts=false, all_pages=false )
      # execute the global search if you have one
      objects = global_search.call(objects,params[:search]) if global_search && params[:search].present?

      [:activerecord, :array].each do |t|

        #column search 
        objects = objects_where(objects, columns_on_steroid, t) 

        #apply filters
        if params[:filters].present?
          params[:filters].each_pair do | k, v |
            filter = columns_on_steroid[k]
            next unless filter.present? && filter[t].present?
            objects = filter[t][:filter_lambda].call(objects, v)
          end
        end

        #order
        if params[:knowledge] && params[:knowledge] && params[:knowledge][:order].present? && (object_order = columns_on_steroid[params[:knowledge][:order]]).present?       
          if(object_order[t] && object_order[t][:order_lambda])
            objects = objects.reorder(nil) if(objects.is_a?(ActiveRecord::Base) || objects.is_a?(ActiveRecord::Relation))
            objects = object_order[t][:order_lambda].call(objects)
          end
        elsif(object_order = columns_on_steroid.select{ |c,v| v[:default_order]}.collect{ |c,v| v[:order_lambda] }).present?
          objects = object_order.call(objects)
        elsif(objects.is_a?(ActiveRecord::Base) || objects.is_a?(ActiveRecord::Relation))
          #objects = objects.order('created_at desc')
        end

      end

      #pagination 
      return (include_counts ? [objects, 1, objects.count] : objects) if all_pages
      if(objects.is_a?(ActiveRecord::Base) || objects.is_a?(ActiveRecord::Relation))
        objects = objects.page(params[:page]).per(OBJECTS_PER_PAGE) 
        total_pages = objects.total_pages
        total_count = objects.total_count
      else 
        total_count = objects.count
        total_pages = total_count / OBJECTS_PER_PAGE.to_f 
        current_offset = OBJECTS_PER_PAGE * ((params[:page] || 1) - 1)
        objects = objects[current_offset..(current_offset + OBJECTS_PER_PAGE)]
      end
      include_counts ? [objects, total_pages, total_count] : objects
    end
  
    def table_csv(objects, columns_on_steroid)
      titles = []
      csvs = CSV.generate do |csv|
        columns_on_steroid.select{ |c,v| v[:download_value_lambda].present? }.each{ |c,v| ((v[:download_label].present?) ? titles.push(*v[:download_label]) : titles << v[:label]) }
        csv << titles
        objects.each do |o|
          vals = []
          columns_on_steroid.select{ |c,v| v[:download_value_lambda].present? }.each do |c,v| 
            vals.push(*v[:download_value_lambda].call(o))
          end
          csv << vals
        end
      end
    end
  
  
    def objects_where(objects, columns_on_steroid, t)
      columns_on_steroid.select{ 
        |c,v| v[t] && v[t][:search_lambda].present? }.each{ 
          |c,v| 
            if(params["search_operator_" + c]) # (v[:datatype].present? && ['date','integer'].include?(v[:datatype]))
              objects = v[t][:search_lambda].call(objects, params["search_" + c], params["search_operator_" + c]) if(params["search_" + c] && !params["search_" + c].blank?) 
            else
              objects = v[t][:search_lambda].call(objects, params["search_" + c]) if(params["search_" + c] && !params["search_" + c].blank?) 
            end
          }
      objects
    end

    def objects_where_date(objects, column, value, operator)
      case operator
      when "<",">=" then
        return objects.where((column + ' ' + operator + ' ?'), (value + " 00:00:00") )
      when ">","<=" then
        return objects.where((column + ' ' + operator + ' ?'), (value + " 23:59:59") )
      when "=" then
        return objects.where((column + ' between ? and ?'), (value + " 00:00:00"), (value + " 23:59:59")  )
      end
    end

    def objects_where_ruby_date(object, column, value, operator)
      value = Date.strptime(value, '%m/%d/%Y').midnight
      case operator
      when "<" then
        return object.send(column) < value
      when ">" then
        return object.send(column) > value + 1.days - 1.seconds
      when "=" then
        return ((object.send(column) > value) && (object.send(column) < (value + 1.days - 1.seconds)))
      end
    end

    def object_where_integer(integer, operator, value)
        case operator
      when "<",">=" then
        return integer.to_f < value.to_f
      when "=" then
        return integer.to_f == value.to_f
      when ">" then
        return integer.to_f > value.to_f
      end
    end

    #save for later
    def objects_where_or(objects, columns_on_steroid)
      where_sql = "" 
      values = []
      
      #search all columns
      if(!query.blank?)
        where_sql += columns_on_steroid.select{ 
          |c,v| v[:or_where_sql].present? }.map{ 
            |c,v| v[:or_where_sql].map{ 
              |w| w[:where] }.join(" or ") }.join(" or ")
        
        columns_on_steroid.select{ 
          |c,v| v[:or_where_sql].present? }.map{ 
            |c,v| v[:or_where_sql].each{ 
              |w| values << ((w[:value]) ? w[:value] : ("%" + query + "%")) }}

        where_sql = ("(" + where_sql + ")") if !where_sql.blank?

        objects = objects.where(where_sql, *values)
      end

      objects
    end
  end
end