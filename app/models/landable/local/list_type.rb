module Landable
  module Local
    class ListType < ActiveRecord::Base
      include Landable::TableName

      lookup_by :list_type, cache: true
    end
  end
end
