module Landable
  module Local
    class Location < ActiveRecord::Base
      include Landable::TableName

      lookup_for :location_type, class_name: LocationType

      belongs_to :logo, class_name: Landable::Asset

      scope :within, ->(miles, geography) do
        meters = miles * 1609.344

        where("public.ST_DWithin(?, display_point, #{meters})", geography)
          .order("public.ST_Distance(display_point, '#{geography}') ASC")
      end

      def within(miles)
        self.class.where("location_code <> ?", location_code).within(miles, display_point)
      end
    end
  end
end
