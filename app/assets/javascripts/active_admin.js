//= require active_admin/base

// Drag-and-drop row ordering: index tables whose rows have a `.handle[data-id][data-sort-url]`.
$(function () {
  $("table.index_table tbody:has(.handle[data-sort-url])").sortable({
    handle: ".handle",
    axis: "y",
    update: function () {
      var handles = $(this).find(".handle");
      $.ajax({
        url: handles.data("sort-url"),
        method: "POST",
        data: { ids: handles.map(function () { return $(this).data("id"); }).get() },
        headers: { "X-CSRF-Token": $("meta[name=csrf-token]").attr("content") }
      });
    }
  });
});
