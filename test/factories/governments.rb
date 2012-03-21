FactoryGirl.define do
  factory :government do
    name "Test government"
    short_name "testgov"
    domain_name "localhost"
    description "nothign"
    admin_name "foo"
    admin_email "foo@bar.com"
    email "bla@bla.com"
  end
end
