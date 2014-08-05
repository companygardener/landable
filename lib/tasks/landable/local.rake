require "csv"

namespace :landable do
  namespace :local do
    desc "Import a CSV file"
    task :import, [:file] => :environment do |t, args|
      abort("This task requires a FILE argument. e.g. rake landable:local:import[FILE]") unless args.file

      rows = CSV.table File.expand_path(args.file)

      table = CSV::Table.new(rows)

      PHONE = /[.+() -]/

      puts "=> Importing Locations"

      table.each do |row|
        categories      = row[:categories].to_s.split(/, ?/)
        payment_methods = row[:payment_types].to_s.split(/, ?/)

        Landable::Local::Location.create!(
          location_name:   row[:name],
          location_code:   row[:store_code],

          address1:        row[:address_line_1],
          address2:        row[:address_line_2],
          city:            row[:city],
          state:           row[:state],
          country:         row[:country],
          zip:             row[:postal_code],

          phone:           row[:main_phone].to_s.gsub(PHONE, ""),
          alternate_phone: row[:alternate_phone].to_s.gsub(PHONE, ""),
          mobile_phone:    row[:mobile].to_s.gsub(PHONE, ""),
          fax_phone:       row[:fax].to_s.gsub(PHONE, ""),

          website_url:     row[:home_page],
          category_ids:    categories.any? ? [*Landable::Local::Category[*categories]].map(&:id) : [],
          hours:           row[:opening_hours],
          display_lat:     row[:latitude],
          display_lng:     row[:longitude],

          # photo_ids:       row[:images],

          description:     row[:description],
          emails:          [row[:email]].compact,

          payment_method_ids: payment_methods.any? ? [*Landable::Local::PaymentMethod[*payment_methods]].map(&:id) : [],

          google_ad_icon_url: row[:ad_icon_url],
          google_ad_phone:    row[:ad_phone],
          google_ad_landing_page_url: row[:ad_landing_page_url]
        )

        print "."
      end

      Landable::Local::Location.connection.execute <<-SQL
        UPDATE landable_local.locations SET display_point = ST_GeographyFromText('SRID=4326;POINT(' || display_lng || ' ' || display_lat || ')');
      SQL

      puts
    end
  end
end
