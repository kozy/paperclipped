module SitePagination
  def self.included(base)
    base.send :include, InstanceMethods
    base.send :prepend_before_filter, :populate_pagination
    base.send :helper_method, :pagination_options
    base.send :alias_method_chain, :process_page, :pagination
  end

  module ClassMethods
  end
  
  module InstanceMethods
    
    def pagination_options
      @pagination_options
    end
  
    def process_page_with_pagination(page)
      @page.pagination_options = pagination_options
      process_page_without_pagination(page)
    end

  protected

    def populate_pagination
      @pagination_options = pagination_defaults.merge({
        :page => params.delete(:page),
        :per_page => params.delete(:per_page)
      })
    end

    def pagination_defaults
      {
        :page => 1, 
        :per_page => request.params[:per_page] || Radiant::Config['pagination.per_page'] || 20
      }
    end
  
  end

end
