//= require tree
//= require dates.crud
//= require agents.crud
//= require subjects.crud
//= require deaccessions.crud
//= require subrecord.crud

$(function() {

  $.fn.init_accession_form = function() {
    $(this).each(function() {
      var $this = $(this);

      if ($this.hasClass("initialised")) {
        return;
      }

      $this.addClass("initialised");


      var addEventBindings = function() {

      };

      addEventBindings();
    });
  };


  $(document).ready(function() {
    $(document).ajaxComplete(function() {
      $("#accession_form:not(.initialised)").init_accession_form();
    });

    $("#accession_form:not(.initialised)").init_accession_form();
  });

});