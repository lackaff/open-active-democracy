# coding: utf-8

namespace :yrpri do
  desc "Seed yrpri.org database"
  task :seed => :environment do
    Category.create(:name=>"Framkvæmdir", :description => "")
    Category.create(:name=>"Skipulagsmál", :description => "")
    Category.create(:name=>"Samgöngur", :description => "")
    Category.create(:name=>"Velferðarmál", :description => "")
    Category.create(:name=>"Ferðamál", :description => "")
    Category.create(:name=>"Umhverfismál", :description => "")
    Category.create(:name=>"Menntamál", :description => "")
    Category.create(:name=>"Frístundir og útivist", :description => "")
    Category.create(:name=>"Íþróttir", :description => "")
    Category.create(:name=>"Menning og listir", :description => "")
    Category.create(:name=>"Mannréttindi", :description => "")
    Category.create(:name=>"Stjórnsýsla", :description => "")
    Category.create(:name=>"Alls konar", :description => "")

    unless partner = Partner.find_by_short_name("dev")
      partner = Partner.create(:name=>"development", :short_name=>"dev")
    end
    Category.create(:name=>"User interface", :partner_id=>partner.id)
    Category.create(:name=>"General", :partner_id=>partner.id)
    Category.create(:name=>"Localization", :partner_id=>partner.id)
    Category.create(:name=>"Data sources", :partner_id=>partner.id)

    p=Partner.new
    p.name = "The European Union and EEA"
    p.short_name = "eu"
    p.geoblocking_enabled = true
    p.geoblocking_open_countries = ["at", "be", "bg", "cy", "cz", "dk", "ee", "fi", "fr", "de", "gr", "hu", "ie", "it", "lv", "lt", "lu", "mt", "nl", "pl", "pt", "ro", "sk", "si", "es", "se", "gb","is","no","li","ch"].join(",")
    p.save

    p=Partner.new
    p.name = "Development"
    p.short_name = "dev"
    p.save

    p=Partner.new
    p.name = "The World"
    p.short_name = "world"
    p.save
  end
end
