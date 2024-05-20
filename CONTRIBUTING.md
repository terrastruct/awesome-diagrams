# Contributing a diagram

Whether you'd like to promote your content or just share a resource and help the
community, your contribution is much appreciated.

To do so is very simple! But in order for the website generator to pick up your diagram,
it must follow a straightforward format:

1. Create a directory under `diagrams/[year]/[month]/[day]/[name]`. That is the date you
   are submitting it. Choose a short, descriptive name. Hyphenate it if multiple words.
2. Create a `diagram.yml` and fill out the template below.
3. Add referenced diagram images, e.g. `1.png`. The extension does not matter, so long as
   you reference it in `diagram.yml` correctly.
4. Once a pull request is opened, it will be promptly reviewed and show up on the website
   within 24 hours of merging.

## `diagram.yml` template

```yaml
schema-version: 0.1

# Required
name: "Green eggs and ham"
images:
  - 1.png
attribution: "https://en.wikipedia.org/wiki/Green_Eggs_and_Ham"
tags:
  - eggs

# Optional
author: Dr. Seuss
description: |
  Green Eggs and Ham is a children's book by Dr. Seuss. It was published by the Beginner Books imprint of Random House on August 12, 1960.
```

### Notes

- You may include multiple images if relevant. They will be displayed like a horizontal
  gallery.
- Please include the author if possible. Sometimes it's obvious, e.g. blog post authors.
  But sometimes a low-effort search is all it takes, e.g. most open-source documentation
  have Git commits showing the original committer of the diagram.
- For the description, a few sentences of text around the diagram briefly explaining it is
  enough.
