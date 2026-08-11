defmodule <%= web_module %>.BlogHTML do
  @moduledoc """
  Templates for published blog content.

  `processed_content` is HTML the publisher already rendered from markdown, so
  it is written with `raw/1`. That is safe here and nowhere else: it arrives
  from the publishing server over an authenticated endpoint, not from a reader.
  """

  use <%= web_module %>, :html

  embed_templates "blog_html/*"
end
