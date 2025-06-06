class PackagesController < ApplicationController
  before_action :set_package, only: [:show]

  def index
    @ecosystem_counts = Package.group(:ecosystem).count
    @ecosystems = @ecosystem_counts.sort_by { |ecosystem, count| -count }.map(&:first)
  end

  def ecosystem
    @ecosystem = params[:ecosystem]
    packages = Package.where(ecosystem: @ecosystem)
                     .where('issues_count > 0')
                     .order('issues_count DESC, name ASC')
    
    @pagy, @packages = pagy(packages)
  end

  def show
    issue_packages = @package.issue_packages
                            .includes(issue: [:repository, :host])
                            .order('issues.created_at DESC')
    
    @pagy, @issue_packages = pagy(issue_packages)
  end

  def search
    @query = params[:q]
    
    if @query.present?
      packages = Package.where("name ILIKE ?", "%#{@query}%")
                       .where('issues_count > 0')
                       .order('issues_count DESC, name ASC')
      
      @pagy, @packages = pagy(packages)
    else
      @pagy, @packages = pagy(Package.none)
    end
  end

  private

  def set_package
    if params[:ecosystem] && params[:name]
      # URL decode the name parameter to handle special characters
      decoded_name = CGI.unescape(params[:name])
      @package = Package.find_by!(ecosystem: params[:ecosystem], name: decoded_name)
    else
      @package = Package.find(params[:id])
    end
  end
end