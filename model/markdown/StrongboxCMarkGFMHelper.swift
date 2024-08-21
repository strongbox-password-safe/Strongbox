//
//  StrongboxCMarkGFMHelper.swift
//  test-libcmark-gfm
//
//  Created by Strongbox on 07/11/2023.
//

import Foundation
import libcmark_gfm

enum CmarkGFMError: Error {
    case generic(description: String)
}

@objc
public class StrongboxCMarkGFMHelper: NSObject {
    private static func addExtension(parser: UnsafeMutablePointer<cmark_parser>, extensionName: String) -> Bool {
        let ext = cmark_find_syntax_extension(extensionName)

        if ext != nil {
            cmark_parser_attach_syntax_extension(parser, ext)
        } else {
            swlog("🔴 Could not add extension: [%@]", extensionName)
            return false
        }

        return true
    }

    @objc
    static func convertToHtmlFragment(markdown: String) throws -> String {
        cmark_gfm_core_extensions_ensure_registered()

        

        let options = CMARK_OPT_FOOTNOTES | CMARK_OPT_HARDBREAKS | CMARK_OPT_VALIDATE_UTF8 | CMARK_OPT_SMART

        guard let parser = cmark_parser_new(options) else {
            swlog("🔴 Error creating cmark parser")
            throw CmarkGFMError.generic(description: " Error creating cmark parser")
        }

        

        

        guard addExtension(parser: parser, extensionName: "strikethrough"),
              addExtension(parser: parser, extensionName: "table"),
              addExtension(parser: parser, extensionName: "autolink"),
              addExtension(parser: parser, extensionName: "tasklist")
        else {
            swlog("🔴 Could not add all GFM markdown extensions")
            throw CmarkGFMError.generic(description: "Could not add all GFM markdown extensions")
        }

        guard let arr = markdown.cString(using: .utf8) else {
            swlog("🔴 Could not convert markdown to UTF8 string")
            throw CmarkGFMError.generic(description: "Could not convert markdown to UTF8 string")
        }

        cmark_parser_feed(parser, arr, arr.count - 1)

        guard let doc = cmark_parser_finish(parser) else {
            swlog("🔴 error in cmark_parser_finish")
            throw CmarkGFMError.generic(description: "error in cmark_parser_finish")
        }

        cmark_parser_free(parser)

        guard let cStrHtml = cmark_render_html(doc, options, nil) else {
            cmark_node_free(doc)
            swlog("🔴 cmark_render_html error")
            throw CmarkGFMError.generic(description: "error in cmark_render_html")
        }

        cmark_node_free(doc)

        let html = String(cString: cStrHtml)

        return html
    }

    @objc
    public static func convertMarkdown(markdown: String, darkMode: Bool, disableMarkdown: Bool) throws -> String {
        if disableMarkdown {
            let lines = markdown.lines.map { line in
                String(format: "<p>\(line.htmlStringEscaped)</p>")
            }

            let markdownHtmlFragment = lines.joined()



            guard let url = Bundle.main.url(forResource: "non-markdown-index", withExtension: "html") else {
                swlog("🔴 Could not load non-markdown-index.html")
                throw CmarkGFMError.generic(description: "Could not load markdown-index.html")
            }
            let templateHtml = try String(contentsOf: url)

            return String(format: templateHtml, markdownHtmlFragment)
        } else {
            let markdownHtmlFragment = try convertToHtmlFragment(markdown: markdown)

            guard let url = Bundle.main.url(forResource: "markdown-index", withExtension: "html") else {
                swlog("🔴 Could not load markdown-index.html")
                throw CmarkGFMError.generic(description: "Could not load markdown-index.html")
            }
            let templateHtml = try String(contentsOf: url)

            let codeHighlightingStylesheet = darkMode ? "stackoverflow-dark.min.css" : "stackoverflow-light.min.css"

            return String(format: templateHtml, codeHighlightingStylesheet, markdownHtmlFragment)
        }
    }
}
