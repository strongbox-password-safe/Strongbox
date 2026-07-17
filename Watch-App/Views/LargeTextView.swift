//
//  LargeTextView.swift
//  Strongbox
//
//  Created by Strongbox on 14/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import MarkdownUI
import SwiftUI

struct LargeTextView: View {
    var value: String
    var markdown: Bool = false
    var pro: Bool

    var body: some View {
        ScrollView {
            if markdown {
                let view = Markdown(value)

                if pro {
                    view
                } else {
                    VStack {
                        ProBadge()

                        view.blur(radius: 7)
                    }
                }
            } else {
                let view = Text(value)
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 48))
                    .minimumScaleFactor(0.4)

                if pro {
                    view
                } else {
                    VStack {
                        ProBadge()

                        view.blur(radius: 7)
                    }
                }
            }
        }
    }
}

#Preview {
    let markdown = """
    # Heading 1

    You can quote text with a `>`.

    > Science is what you know, philosophy is what you don't know.

    – Bertrand Russell

    > Out of the crooked timber of humanity no straight thing was ever made.

    – Immanuel Kant

    ## Heading 2 - Strikethrough
    "~~A strikethrough example~~"

    ### Heading 3 - Code Samples
    #### Swift
    ```swift
    let skynet = new AGI()
    ```

    #### HTML
    ```
    <html>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="stackoverflow-dark.min.css">
    <script src="highlight.min.js"></script>
    <script>hljs.highlightAll();</script>
    <style>
        :root {
            color-scheme: light dark;
        }

        .markdown-body {
            box-sizing: border-box;
            min-width: 200px;
            max-width: 980px;
            margin: 0 auto;
            padding: 15px;
        }

        @media (max-width: 767px) {
            .markdown-body {
                padding: 15px;
            }
        }
    </style>

    <link rel="stylesheet" href="github-markdown.css">

    <body>
        <article class="markdown-body">
            %@
        </article>
    </body>
    </html>
    ```
    #### Heading 4 - Tables
    | Left-aligned | Center-aligned | Right-aligned |
    | :---         |     :---:      |          ---: |
    | ↖️   | ⬆️ | ↗️ |
    | ⬅️   | 🚀 | ➡️ |
    | ↙️   | ⬇️ | ↘️ |

    ---

    #### Tasklists

    * [ ] to do
    * [x] done

    ---

    ##### Heading 5 - AutoLinks
    Autolink literals

    www.example.com, https://example.com, and contact@example.com.

    ###### Heading 6 - Footnotes

    A note[^1]

    [^1]: Plato, The Timeaus
    """
    return LargeTextView(value: markdown, markdown: true, pro: true)
}
