class Vegetable < ActiveRecord::Base

  validates :name, presence: true

  def self.inheritance_column
    'custom_type'
  end
end

class Cucumber < Vegetable
end

class Cabbage < Vegetable
end

class GreenCabbage < Cabbage
end

class KingCole < GreenCabbage
end

class RedCabbage < Cabbage
  belongs_to :seller, :class_name => 'Company'
end
