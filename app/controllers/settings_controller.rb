class SettingsController < ApplicationController
  
  before_filter :login_required
  before_filter :get_user

  # GET /settings
  def index
    @partners = Partner.find(:all, :conditions => "is_optin = true and status = 'active' and id <> 3")
    @page_title = tr("Your {government_name} settings", "controller/settings", :government_name => tr(current_government.name,"Name from database"))
  end

  # PUT /settings
  def update
    respond_to do |format|
      wrong_password = false
      users = User.find_all_by_email(params[:user][:email])
      old_user, new_user = users.sort_by(&:id)
      if users.count > 1 and new_user.facebook_id
        password = params[:user].delete(:password)
        if password == old_user.password
          @user = old_user
          @user.facebook_id = new_user.facebook_id
          @user.save
          new_user.email = new_user.email + ".facebook_merge.#{Time.now.to_i}"
          new_user.status = "deleted"
          new_user.save
        else
          wrong_password = true
        end
      end
      if wrong_password
        flash[:notice] = tr("Password incorrect", "controller/passwords")
        format.html { render :action => "index" }
      elsif @user.update_attributes(params[:user])
        flash[:notice] = tr("Saved your settings", "controller/settings")
        format.html {
          redirect_to("/") 
        }
      else
        format.html { render :action => "index" }
      end
    end
  end

  # GET /settings/signups
  def signups
    @page_title = tr("Your email notifications", "controller/settings", :government_name => tr(current_government.name,"Name from database"))
    @rss_url = url_for(:only_path => false, :controller => "rss", :action => "your_notifications", :format => "rss", :c => current_user.rss_code)
    @partners = Partner.find(:all, :conditions => "is_optin = true and status = 'active' and id <> 3")
  end

  # GET /settings/picture
  def picture
    @page_title = tr("Your picture", "controller/settings")
  end

  def picture_save
    @user = current_user
    respond_to do |format|
      if @user.update_attributes(params[:user])
        ActivityUserPictureNew.create(:user => @user)   
        flash[:notice] = tr("Picture uploaded successfully", "controller/settings")
        format.html { redirect_to(:action => :picture) }
      else
        format.html { render :action => "picture" }
      end
    end
  end
    
  # GET /settings/delete
  def delete
    @page_title = tr("Delete your {government_name} account", "controller/settings", :government_name => tr(current_government.name,"Name from database"))
  end

  # DELETE /settings
  def destroy
    @user.delete!
    self.current_user.forget_me
    cookies.delete :auth_token
    reset_session    
    flash[:notice] = tr("Your account was deleted. Good bye!", "controller/settings")
    redirect_to "/" and return
  end

  private
  def get_user
    @user = User.find(current_user.id)
  end

end
