module Landable
  module Local
    class Category < ActiveRecord::Base
      include Landable::TableName

      lookup_by :category, find_or_create: true
    end
  end
end
