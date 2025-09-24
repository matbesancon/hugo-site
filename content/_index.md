---
# Leave the homepage title empty to use the site title
title:
date: 2022-10-24
type: landing

sections:
  - block: about.biography
    id: about
    content:
      title: Biography
      # Choose a user profile to display (a folder name within `content/authors/`)
      username: admin
      # Override your bio text from `authors/admin/_index.md`?
      text:
  - block: experience
    id: experience
    content:
      title: Experience
      # Date format for experience
      #   Refer to https://wowchemy.com/docs/customization/#date-format
      date_format: Jan 2006
      # Experiences.
      #   Add/remove as many `experience` items below as you like.
      #   Required fields are `title`, `company`, and `date_start`.
      #   Leave `date_end` empty if it's your current employer.
      #   Begin multi-line descriptions with YAML's `|2-` multi-line prefix.
      items:
        - title: Associate Researcher
          company: Inria Grenoble
          company_url: 'https://www.inria.fr/en/inria-centre-university-grenoble-alpes'
          company_logo:
          location: Grenoble, France
          date_start: '2024-01-01'
          date_end: ''
          description: Research in optimization.
        - title: Postdoctoral Researcher
          company: Zuse Institute Berlin
          company_url: 'https://www.zib.de/'
          company_logo:
          location: Berlin, Germany
          date_start: '2021-01-01'
          date_end: '2023-12-31'
          description: Research in optimization methods and computation.
        - title: Doctoral Researcher
          company: Polytechnique Montréal, Inria Lille
          company_url: ''
          company_logo:
          location: Montréal, Canada & Lille, France
          date_start: '2017-09-01'
          date_end: '2020-12-11'
          description: Double PhD program in mathematical optimization for pricing of demand response programs in smart grids.
        - title: Research Engineer, Data Scientist
          company: Equisense SAS
          company_url: ''
          company_logo:
          location: Lille, France
          date_start: '2016-07-01'
          date_end: '2017-08-04'
          description:  Research and development for a startup building connected devices and associated products for horse-riders.
        - title: Master's Thesis
          company: Siemens AG, Digital Industries
          company_url: ''
          company_logo:
          location: Karslruhe, Germany
          date_start: '2016-02-01'
          date_end: '2016-07-31'
          description: Stochastic models for event monitoring in automated systems.
        - title: Junior Engineer Placement
          company: ArcelorMittal Hamburg GmbH
          company_url: ''
          company_logo:
          location: Hamburg, Germany
          date_start: '2014-08-01'
          date_end: '2015-01-30'
          description: Quantification and analysis of material losses in a steel rolling mill.

  - block: collection
    id: publications
    content:
      title: Publications
      subtitle: Filter publications [here](./publication/).
      text:
      filters:
        folders:
          - publication
        exclude_featured: false
    design:
      columns: '2'
      view: citation
  - block: collection
    id: posts
    content:
      title: Blog Posts
      subtitle: 'See all posts [here](./post/).
'
      text: ''
      # Choose how many pages you would like to display (0 = all pages)
      count: 5
      # Filter on criteria
      filters:
        folders:
          - post
        author: ""
        category: ""
        tag: ""
        exclude_featured: false
        exclude_future: false
        exclude_past: false
        publication_type: ""
      # Choose how many pages you would like to offset by
      offset: 0
      # Page order: descending (desc) or ascending (asc) date.
      order: desc
    design:
      # Choose a layout view
      view: compact
      columns: '2'
  # - block: collection
  #   id: talks
  #   content:
  #     title: Recent & Upcoming Talks
  #     filters:
  #       folders:
  #         - event
  #   design:
  #     columns: '2'
  #     view: compact
  - block: markdown
    id: workwithme
    content:
      title: Work with me
      subtitle: If you want to join my group and work with me, please read the information [here](./workwithme/).
      text:
    design:
      columns: '1'
  - block: contact
    id: contact
    content:
      title: Contact
      subtitle:
      text: The most reliable way to reach me is per email.
      # Contact (add or remove contact options as necessary)
      email: mathieu(dot)besancon+contact(at)gmail.com
      # address:
      #   street: 450 Serra Mall
      #   city: Stanford
      #   region: CA
      #   postcode: '94305'
      #   country: United States
      #   country_code: US
      # directions: Enter Building 1 and take the stairs to Office 200 on Floor 2
      # office_hours:
      #   - 'Monday 10:00 to 13:00'
      #   - 'Wednesday 09:00 to 10:00'
      contact_links:
        - icon: bluesky
          icon_pack: fab
          link: 'https://matbesancon.bsky.social'
          name: 'Bluesky'
        - icon: google-scholar
          icon_pack: ai
          link: 'https://scholar.google.com/citations?user=-xStCAIAAAAJ'
          name: Google Scholar
        - icon: github
          icon_pack: fab
          link: https://github.com/matbesancon
          name: GitHub
        - icon: orcid
          icon_pack: ai
          link: https://orcid.org/0000-0002-6284-3033
          name: Orcid
        - icon: linkedin
          icon_pack: fab
          link: https://linkedin.com/in/mbesancon
          name: LinkedIn
      # Automatically link email and phone or display as text?
      autolink: true
      # Email form provider
    design:
      columns: '1'
---
