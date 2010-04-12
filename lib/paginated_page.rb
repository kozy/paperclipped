module PaginatedPage
  def self.included(base)
    base.send :attr_accessor, :pagination_options
  end  
end

