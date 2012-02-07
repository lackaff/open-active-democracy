# coding: utf-8

namespace :fjarhagur_2013 do
  desc "create betri fjarhagsaaetlun 2013 partner"
  task :init => :environment do
    name = "Betri fjárhagsáætlun 2013"
    short = "betri-fjarhagsaaetlun-2013"
    if not Partner.find_by_name(name)
      Partner.create(
        name: name,
        short_name: short,
        parent_tag: "Betri fjárhagsáætlun 2013",
        message_to_users: '<br>Reykjavíkurborg óskar sérstaklega eftir ábendingum frá borgarbúum vegna fjárhagsáætlanagerðar fyrir árið 2013. Óskað er eftir hugmyndum sem gætu komið til greina eða ábendingum um sparnað í rekstri eða þjónustu borgarinnar. Skráðir notendur geta sett inn hugmyndir með því að <a href="http://betri-fjarhagsaaetlun-2013.betrireykjavik.is/priorities/new">smella hér</a> til 20. febrúar.'
      )
    end
  end

  desc "make betri fjarhagsaaetlun 2013 active"
  task :make_active => :environment do
    Partner.transaction do
      Partner.all.each do |partner|
        if partner.short_name == "betri-fjarhagsaaetlun-2013"
          partner.status = "passive"
          partner.save
        end
      end
    end
  end

  desc "make betri fjarhagsaaetlun 2013 inactive"
  task :make_inactive => :environment do
    Partner.transaction do
      Partner.all.each do |partner|
        if partner.short_name == "betri-fjarhagsaaetlun-2013"
          partner.status = "inactive"
          partner.save
        end
      end
    end
  end
end
