//= require bootstrap-multiselect
//= require bootstrap-datepicker


var TableOnSteroids =  {
  new: function(element) {
    this.$element = $(element);
    if (!this.$element[0]) return;
    this.initColumnSelection();
    this.initDatePicker();
    this.observe();
    $('.filter-cell-left select[multiple]').multiselect({inheritClass: true});
  },
  initColumnSelection: function(){
    var _this = this;
    $('.column_filter select[multiple]').multiselect({
      inheritClass: true, 
      buttonWidth: '400px',
      maxHeight: 250,
      onChange: function(option, checked, select) {
        var tableOnSteroidId = $(option).closest(".table-on-steroids").attr("id");
        _this.$element.find('.column.' + tableOnSteroidId).addClass('d-none');
        option.parent().val().forEach(function(element) {
          _this.$element.find('.column-'+element).removeClass('d-none')+' .'+tableOnSteroidId
        });
      },
      buttonText: function(options, select) {
        if (options.length > 4) {
            return options.length + ' columns displayed';
        }
         else {
             var labels = [];
             options.each(function() {
                 if ($(this).attr('label') !== undefined) {
                     labels.push($(this).attr('label'));
                 }
                 else {
                     labels.push($(this).html());
                 }
             });
             return labels.join(', ') + '';
         }
      }
    });
  },
  observe: function(){
    var _this = this;
    this.$element.on('change', '.filter-control', function(e) { _this.filterControl(e)});
  },
  initDatePicker: function(){
    this.$element.find('.date_search').datepicker({ });
  },
  filterControl: function(e){
    if($(e.currentTarget).hasClass("table-on-steroid-form-operator"));
    {
      var operator_value_field = $(e.currentTarget).attr("operator_value_field");
      if(operator_value_field != "undefined" && $("#" + operator_value_field).val() == "")
        return;
    }
    if($(e.currentTarget).attr("data-table-on-steroid-id") || $(e.currentTarget).attr("table_on_steroid_id"))
    {
      var table_on_steroid_id = $(e.currentTarget).attr("data-table-on-steroid-id") || $(e.currentTarget).attr("table_on_steroid_id");
      $('#page').val('');
      $('#knowledge_base_filters' + table_on_steroid_id).submit();
    }
  }
}

$(document).ready(function() {
  TableOnSteroids.new('.table-on-steroids');
});

$(document).on('turbolinks:load', function() {
  TableOnSteroids.new('.table-on-steroids');
});
