module Landable
  module Local
    class List < ActiveRecord::Base
      include Landable::TableName
    end
  end
end
