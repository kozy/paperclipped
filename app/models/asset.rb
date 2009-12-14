class Asset < ActiveRecord::Base
  named_scope :others, lambda {{:conditions => AssetType.other_condition}}
  named_scope :not_others, lambda {{:conditions => AssetType.non_other_condition}}
  named_scope :newest_first, { :order => 'created_at DESC'}

  has_many :page_attachments, :dependent => :destroy
  has_many :pages, :through => :page_attachments

  belongs_to :created_by, :class_name => 'User'
  belongs_to :updated_by, :class_name => 'User'
  
  has_attached_file :asset,
                    :processors => lambda {|instance| instance.paperclip_processors },
                    :styles => lambda {|instance| instance.paperclip_styles },
                    :whiny_thumbnails => false,
                    :storage => Radiant::Config["assets.storage"] == "s3" ? :s3 : :filesystem, 
                    :s3_credentials => {
                      :access_key_id => Radiant::Config["assets.s3.key"],
                      :secret_access_key => Radiant::Config["assets.s3.secret"]
                    },
                    :bucket => Radiant::Config["assets.s3.bucket"],
                    :url => Radiant::Config["assets.url"] ? Radiant::Config["assets.url"] : "/:class/:id/:basename:no_original_style.:extension", 
                    :path => Radiant::Config["assets.path"] ? Radiant::Config["assets.path"] : ":rails_root/public/:class/:id/:basename:no_original_style.:extension"

  before_save :assign_title
  after_post_process :note_dimensions
                                 
  validates_attachment_presence :asset, :message => "You must choose a file to upload!"
  validates_attachment_content_type :asset, 
    :content_type => Radiant::Config["assets.content_types"].gsub(' ','').split(',') if Radiant::Config.table_exists? && Radiant::Config["assets.content_types"] && Radiant::Config["assets.skip_filetype_validation"] == nil
  validates_attachment_size :asset, 
    :less_than => Radiant::Config["assets.max_asset_size"].to_i.megabytes if Radiant::Config.table_exists? && Radiant::Config["assets.max_asset_size"]

  def asset_type
    AssetType.from(asset_content_type)
  end
  delegate :paperclip_processors, :paperclip_styles, :style_dimensions, :style_format, :to => :asset_type

  def other?
    asset_type.nil?
  end

  def thumbnail(size='original')
    return asset.url if size == 'original'
    case 
      when self.pdf?   : "/images/assets/pdf_#{size.to_s}.png"
      when self.movie? : "/images/assets/movie_#{size.to_s}.png"
      when self.video? : "/images/assets/movie_#{size.to_s}.png"
      when self.swf? : "/images/assets/movie_#{size.to_s}.png" #TODO: special icon for swf-files
      when self.audio? : "/images/assets/audio_#{size.to_s}.png"
      when self.other? : "/images/assets/doc_#{size.to_s}.png"
    else
      self.asset.url(size.to_sym)
    end
  end

  def basename
    File.basename(asset_file_name, ".*") if asset_file_name
  end

  def extension
    asset_file_name.split('.').last.downcase if asset_file_name
  end

  # we avoid going back to the file so as not to block page requests with imagemagick calls
  def geometry(style_name='original')
    if style_name == 'original'
      Paperclip::Geometry.parse("#{original_width}x#{original_height}")
    else
      Paperclip::Geometry.parse(style_dimensions(style_name))
    end
  end

  def geometry_from_file
    Paperclip::Geometry.from_file(asset.path)
  rescue Paperclip::NotIdentifiedByImageMagickError
    Paperclip::Geometry.parse("0x0")
  end

  def width(size='original')
    image? ? geometry(size).width : 0
  end

  def height(size='original')
    image? ? geometry(size).height : 0
  end

  def square?(size='original')
    image? && geometry(size).square?
  end

  def vertical?(size='original')
    image? && geometry(size).vertical?
  end

  def horizontal?(size='original')
    image? && geometry(size).horizontal?
  end
  
private

  def assign_title
    self.title = basename if title.blank?
  end
  
  def note_dimensions
    if image? && (geometry = geometry_from_file)
      self.original_width = geometry.width
      self.original_height = geometry.height
      self.original_extension = extension
      true
    end
  rescue
    false
  end

  class << self
    def known_types
      AssetType.known_types
    end
    
    def search(search, filter, page)
      unless search.blank?

        search_cond_sql = []
        search_cond_sql << 'LOWER(asset_file_name) LIKE (:term)'
        search_cond_sql << 'LOWER(title) LIKE (:term)'
        search_cond_sql << 'LOWER(caption) LIKE (:term)'
        cond_sql = search_cond_sql.join(" OR ")

        @conditions = [cond_sql, {:term => "%#{search.downcase}%" }]
      else
        @conditions = []
      end

      options = { :conditions => @conditions,
                  :order => 'created_at DESC',
                  :page => page,
                  :per_page => 10 }

      @asset_types = filter.blank? ? [] : filter.keys
      unless @asset_types.empty?
        options[:total_entries] = count_with_asset_types(@asset_types, :conditions => @conditions)
        Asset.paginate_by_asset_types(@asset_types, :all, options )
      else
        Asset.paginate(:all, options)
      end
    end

    def find_all_by_asset_types(asset_types, *args)
      with_asset_types(asset_types) { find *args }
    end
    
    def count_with_asset_types(asset_types, *args)
      with_asset_types(asset_types) { count *args }
    end
    
    def with_asset_types(asset_types, &block)
      with_scope(:find => { :conditions => AssetType.conditions_for(asset_types) }, &block)
    end
    
  end

  def self.eigenclass
    class << self; self; end    # returns the return value of class << self block, which is self (as defined within that block)
  end

  def self.define_class_method(name, &block)
    eigenclass.send :define_method, name, &block
  end

end
