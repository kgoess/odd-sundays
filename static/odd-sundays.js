$(document).ready(function(){
  function sortDateDesc(a, b) {
    if (a[0] < b[0]) {
        return 1
    }
    if (a[0] > b[0]) {
        return -1
    }
    if (a[1] && b[1]) {
        // if the dates match, sort by title asc
        if (a[1] > b[1]) {
            return 1
        }
        if (a[1] < b[1]) {
            return -1
        }
    }
    return 0;
  }

  function sortTitleAsc(a, b) {
      if (a[1] > b[1]) {
          return 1
      }
      if (a[1] < b[1]) {
          return -1
      }
      return 1;
  }

  function sortRows(listContainer, sortType) {
    var newArray = [];
    listContainer.children("div[class='recording-row']").clone().each(function(i, el) {
        newArray.push([
            el.getAttribute('sort-updated-date'),
            el.getAttribute('sort-recording-title'),
            el,
        ]);
    });
    if (sortType === 'updated-date') {
        newArray.sort(sortDateDesc);
    } else {
        newArray.sort(sortTitleAsc);
    }
    listContainer.children("div[class='recording-row']").each(function(i, el) {
        $(el).replaceWith($(newArray[i][2]));
    });
  }

  $("#sort-control").on("change", function(e) {
    var listContainer = $('.recording-list');
    var sortType;
    var selectbox = e.target;
    var selected = $(selectbox.options[selectbox.selectedIndex]).attr("name");
    if (selected === "title") {
        sortType = 'title';
    } else { // updated-date
        sortType = 'updated-date';
    }
        
    sortRows(listContainer, sortType);
  });

    $(".logflipper").on("focusin", function(e) {
        var el = e.target;
        if (el.value === el.getAttribute('data-prompt') ||
            el.value === el.getAttribute('data-secondprompt')
        ) {

            el.value = '';
        }
    });
    $(".logflipper").on('blur', function(e) {
        var el = e.target;
        if (el.value === '') {
            // el.setAttribute('value', el.getAttribute('data-secondprompt'));
            el.value = el.getAttribute('data-secondprompt');
        }
    });
    $(".logflipper").on('input', function(e) {
        var el = e.target;
    });

    var somethingChangedInForm = false;
    $("#edit-recording-form input,textarea").on('input', function(e) {
        somethingChangedInForm = true;
    });

    $("#log-form-submit-button").on('click', function(e) {
        if (somethingChangedInForm) {
            var answer = confirm("There are unsaved changes in the edit form above. You should hit that 'Save' button before adding a log message down here. Continue anyway?");
            if (! answer) {
                e.preventDefault();
            }
        }
    });
});
