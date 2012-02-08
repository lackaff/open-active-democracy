# coding: utf-8

namespace :hverfapottar do

  desc "printout dns names"
  task :print_dns_names => :environment do
    hverfi = {
      'Árbær'       => 'arbaer',
      'Breiðholt'   => 'breidholt',
      'Grafarvogur' => 'grafarvogur',
      'Hlíðar'      => 'hlidar',
      'Kjalarnes'   => 'kjalarnes',
      'Laugardalur' => 'laugardalur',
      'Miðborg'     => 'midborg',
      'Vesturbær'   => 'vesturbaer',
      'Háaleiti- og bústaðir' => 'haaleiti',
      'Grafarholt og Úlfarsárdalur' => 'grafarholt',
    }
    dns_names = ""
    hverfi.each do |name, short_name|
      puts "betri-hverfi-#{short_name}.betrireykjavik.is"
      dns_names += "betri-hverfi-#{short_name}.betrireykjavik.is "
    end
    puts dns_names
  end

  desc "initialize hverfapottar"
  task :init => :environment do
    hverfi = {
      'Árbær'       => 'arbaer',
      'Breiðholt'   => 'breidholt',
      'Grafarvogur' => 'grafarvogur',
      'Hlíðar'      => 'hlidar',
      'Kjalarnes'   => 'kjalarnes',
      'Laugardalur' => 'laugardalur',
      'Miðborg'     => 'midborg',
      'Vesturbær'   => 'vesturbaer',
      'Háaleiti- og bústaðir' => 'haaleiti',
      'Grafarholt og Úlfarsárdalur' => 'grafarholt',
    }
    partner_tags = ["Maintenance projects", "New development projects"]

    PortletContainer.delete_all("partner_id IS NOT NULL")

    Partner.transaction do
      partner_tags.each do |tag_name|
        Tag.find_or_create_by_name(tag_name)
        template_name = "priorities.#{tag_name.downcase.gsub(/\s/, '_')}"
        template = PortletTemplate.find_or_create_by_name(template_name)
        template.portlet_template_category_id = PortletTemplateCategory.find_by_name("priorities.name")
        template.tag = tag_name
        template.item_limit = 3
        template.partial_name = "priority_list"
        template.locals_data_function = "setup_priorities_tagged"
        template.save
      end

      hverfi.each do |name, short_name|
        next if Partner.find_by_name(name)
        Partner.create(
          name: name,
          short_name: "betri-hverfi-#{short_name}",
          required_tags: partner_tags.join(','),
          message_for_new_priority: "Priorities added as neighborhood projects must be either smaller new construction or maintenance projects which can affect the environment and possibilities for outdoors enjoyment, adds facilities for games and recreation or be projects which encourages cycling, better facilities and possibilities for pedestrians or users of the bus system.",
        )
      end
    end
  end

  desc "add hverfapottar portlets"
  task :add_portlets => :environment do
    PortletTemplate.create(
        name: "New Development Projects",
        portlet_template_category_id: 1,
        locals_data_function: "setup_priorities_tagged",
        partial_name: "priority_list",
        tag: "New development projects",
        item_limit: 3
    )
    PortletTemplate.create(
        name: "Maintenance Projects",
        portlet_template_category_id: 1,
        locals_data_function: "setup_priorities_tagged",
        partial_name: "priority_list",
        tag: "Maintenance projects",
        item_limit: 3
    )
  end

  desc "add parent tag"
  task :add_parent_tag => :environment do
    Partner.transaction do
      Partner.all.each do |partner|
        if partner.short_name =~ /^betri-hverfi/
          partner.parent_tag = "Betri hverfi"
          partner.save
        end
      end
    end
  end

  desc "make hverfapottar active"
  task :make_active => :environment do
    Partner.transaction do
      Partner.all.each do |partner|
        if partner.short_name =~ /^betri-hverfi/
          partner.status = "passive"
          partner.save
        end
      end
    end
  end

  desc "make hverfapottar inactive"
  task :make_inactive => :environment do
    Partner.transaction do
      Partner.all.each do |partner|
        if partner.short_name =~ /^betri-hverfi/
          partner.status = "inactive"
          partner.save
        end
      end
    end
  end
end
