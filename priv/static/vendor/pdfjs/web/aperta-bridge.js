// Tiny bridge between the vendored PDF.js viewer (loaded inside an <iframe>)
// and the parent LiveView. Injected into viewer.html by
// `mix aperta.vendor.pdfjs`.
//
// Out: pagesloaded / pagechanging events from the PDF.js event bus are
// forwarded to the parent window via `postMessage`.
// In: `pdfjs:set-page` messages from the parent drive
// `PDFViewerApplication.page`.
(function () {
  "use strict";

  function wireEventBus() {
    var app = window.PDFViewerApplication;
    if (!app || !app.initializedPromise) return;

    app.initializedPromise.then(function () {
      var bus = app.eventBus;
      if (!bus) return;

      bus.on("pagesloaded", function (evt) {
        window.parent.postMessage(
          {
            type: "pdfjs:pagesloaded",
            numPages: evt.pagesCount || (app.pdfDocument && app.pdfDocument.numPages)
          },
          "*"
        );
      });

      bus.on("pagechanging", function (evt) {
        window.parent.postMessage(
          { type: "pdfjs:pagechanging", pageNumber: evt.pageNumber },
          "*"
        );
      });
    });
  }

  if (window.PDFViewerApplication) {
    wireEventBus();
  } else {
    window.addEventListener("webviewerloaded", wireEventBus, { once: true });
  }

  window.addEventListener("message", function (event) {
    var data = event.data;
    if (!data || data.type !== "pdfjs:set-page") return;

    var page = Number(data.page);
    if (!Number.isInteger(page) || page < 1) return;

    var app = window.PDFViewerApplication;
    if (!app || !app.initializedPromise) return;

    app.initializedPromise.then(function () {
      if (app.pdfViewer && app.pdfViewer.currentPageNumber !== page) {
        app.page = page;
      }
    });
  });
})();
