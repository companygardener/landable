module Landable
  module Local
    class PaymentMethod < ActiveRecord::Base
      include Landable::TableName

      lookup_by :payment_method, cache: true
    end
  end
end
