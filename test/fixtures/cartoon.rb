class Cartoon < ActiveRecord::Base
  acts_as_ordered :order => 'first_name'
end

class ReversedCartoon < ActiveRecord::Base
  self.table_name = "cartoons"
  acts_as_ordered :order => 'last_name desc'
end

class WrappedCartoon < ActiveRecord::Base
  self.table_name = "cartoons"
  acts_as_ordered :order => 'last_name', :wrap => true
end

class SillyCartoon < ActiveRecord::Base
  self.table_name = "cartoons"
  acts_as_ordered :if => lambda { |c| c.first_name =~ /e/i }
end

class FunnyCartoon < ActiveRecord::Base
  self.table_name = "cartoons"
  acts_as_ordered :if => [lambda { |r| r.last_name_contains_u? }], :wrap => true

  def last_name_contains_u?
    last_name =~ /u/
  end
end
