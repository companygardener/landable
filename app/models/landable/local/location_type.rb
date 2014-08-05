module Landable
  module Local
    class LocationType < ActiveRecord::Base
      include Landable::TableName

      lookup_by :location_type, cache: true
    end
  end
end
