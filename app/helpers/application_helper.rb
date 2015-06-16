module ApplicationHelper

 def bootstrap_class_for flash_type
    { success: "alert-success", error: "alert-danger", alert: "alert-warning", notice: "alert-info" }[flash_type] || flash_type.to_s
  end
 
  def flash_messages(opts = {})
    flash.each do |msg_type, message|
      concat(content_tag(:div, message, class: "alert alert-info fade in") do 
              concat content_tag(:button, 'x', class: "close", data: { dismiss: 'alert' })
              concat message 
            end)
    end
    nil
  end

  def authorized?(id)
    if current_user and User.find_by_email(current_user.email).guild_id and User.find_by_email(current_user.email).guild_id == id or current_user and User.find_by_email(current_user.email).assistant and User.find_by_email(current_user.email).assistant == id then return true else return false end
  end

  def authorized_full?(id)
    if current_user and User.find_by_email(current_user.email).guild_id and User.find_by_email(current_user.email).guild_id == id then return true else return false end
  end

end
