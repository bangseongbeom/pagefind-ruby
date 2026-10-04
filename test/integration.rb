require "pagefind"

html_content = <<~HTML
  <html>
    <body>
      <main>
        <h1>Example HTML</h1>
        <p>This is an example HTML page.</p>
      </main>
    </body>
  </html>
HTML

Pagefind::Index.open(root_selector: "main", logfile: "index.log", output_path: "./output", verbose: true) do |index|
  new_file = index.add_html_file(
    content: html_content,
    url: "https://example.com",
    source_path: "other/example.html"
  )
  new_record = index.add_custom_record(
    url: "/elephants/",
    content: "Some testing content regarding elephants",
    language: "en",
    meta: {title: "Elephants"}
  )
  new_dir = index.add_directory("./public")
  pp new_file, new_record, new_dir

  index.get_files.each do |file|
    puts "#{file[:content].bytesize.to_s.rjust(10)}B #{file[:path]}"
  end
end
