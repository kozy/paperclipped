class AssetsController < ApplicationController

  def show
    @asset = Asset.find(params[:id])
    response.headers['X-Accel-Redirect'] = @asset.asset.path
    send_file @asset.asset.path, :type => @asset.asset_content_type, :x_sendfile => true
  end
  
end
