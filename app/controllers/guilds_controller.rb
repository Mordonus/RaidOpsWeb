class GuildsController < ApplicationController
	require 'net/ftp'
	require 'stringio'

	skip_before_filter :require_login, only: [:index, :show,:items_all,:download,:recent_activity]
	before_filter do
	    if request.ssl? && Rails.env.production?
	      redirect_to :protocol => 'http://', :status => :moved_permanently
	    end
  	end

	def new
		if User.find_by_email(current_user.email).guild_id != nil then
			redirect_to Guild.find(User.find_by_email(current_user.email).guild_id) , notice: 'You have already created guild , remove this one first'
		else
			@guild = Guild.new
		end
	end

	def show
   		@guild = Guild.find(params[:id])
   		members = Array.new
   		@edited = Array.new   		
   		for member in @guild.guild_members do
   			edit_member = GuildMember.find_by_edit_flag(member.id)
   			if edit_member then
   				members.push(edit_member.id)
   				@edited.push(edit_member.id)
   			elsif member.name != "Guild Bank" then
   				members.push(member.id)
   			end
   		end
   		@members_grid = initialize_grid(GuildMember.where(id: members),:order => 'guild_members.pr',:order_direction => 'desc')
  	end

  	def index
  		@guilds_grid = initialize_grid(Guild.all)
  	end
  	def download
  		begin
	  		f = ""
		  	ftp = Net::FTP.new
			ftp.connect('31.220.16.113')
			ftp.login('u292965448', ENV['FTP_PASS'])
			ftp.passive = true
			filename = "/public_html/guild_json_#{params[:id]}.txt"
			raw = StringIO.new('')
			ftp.retrbinary('RETR ' + filename, 4096) { |data|
			raw << data
			}
			ftp.close
			raw.rewind
			send_data raw.read, :filename => "guild_json_#{params[:id]}.txt"
		rescue
	 		redirect_to Guild.find(params[:id]) , notice: 'Download failed'
	 	end
	end

  	def items_all
  	  @guild = Guild.find(params[:id])
  	  @item_owners = {}
  	  Item.where(of_guild_id: params[:id]).each do |item|
  	  	@item_owners[item.timestamp] = item.of_member_id
  	  end
      @items_grid = initialize_grid(Item.where(of_guild_id: params[:id]),:include => :guild_member)
    end

    def recent_activity
    	@guild = Guild.find(params[:id])
    	@timeline_data = Hash.new
    	@EP_gain_data = Hash.new
    	@GP_gain_data = Hash.new
    	@log = Log.where("n_date = ?",params[:event])[0] if params[:event]
    	for member in @guild.guild_members do
    		for log in member.logs do
	    		if log.n_date and not @timeline_data[log.n_date.to_i] then
	    			@timeline_data[log.n_date.to_i] = {:event => log.strComment , :y => 1 ,:time => log.n_date.to_i}
	    		elsif log.n_date then
					@timeline_data[log.n_date.to_i][:y] += 1 if @timeline_data[log.n_date.to_i][:event] == log.strComment
	    		end

	    		if log.strType == '{EP}' then
		    		if log.n_date and not @EP_gain_data[log.n_date.to_i] then
						@EP_gain_data[log.n_date.to_i] = {:event => log.strComment , :y => log.strModifier.to_i ,:time => log.n_date.to_i}
		    		elsif log.n_date then
						@EP_gain_data[log.n_date.to_i][:y] += log.strModifier.to_i
		    		end
				elsif log.n_date then
					@EP_gain_data[log.n_date.to_i] = nil
				end	
	    	end
    	end
		dates = Array.new
		affected_counts = Array.new
		ep_counts = Array.new
		removed_keys = Array.new
		nMaxEvents = @guild.max_events
		counter = 1
		for key in @timeline_data.keys.sort_by { |time, affected| time }.reverse do
			if counter <= nMaxEvents then
				if @timeline_data[key][:y] >= @guild.min_affected
					dates.insert(0,Time.at(key).strftime('%d/%m/%Y , %T'))
					affected_counts.insert(0,@timeline_data[key])
					counter += 1
				else
					removed_keys.push(key)
				end
			else removed_keys.push(key) end
		end	

		for key in @EP_gain_data.keys.sort_by { |time, affected| time }.reverse do
			if not removed_keys.index(key)
				ep_counts.insert(0,@EP_gain_data[key]) 
			end
		end	

		@chart = LazyHighCharts::HighChart.new('graph') do |f|
		  f.title(:text => "Recent activity")
		  f.xAxis(:categories => dates)
		  f.series(:name => "Affected", :yAxis => 0, :data => affected_counts)
		  f.series(:name => "EP gain", :yAxis => 1, :data => ep_counts)

		  f.yAxis [
		    {:title => {:text => "Affected", :margin => 70} },
		    {:title => {:text => "EP gain"}, :opposite => true},
		  ]

		  f.legend(:align => 'right', :verticalAlign => 'top', :y => 75, :x => -50, :layout => 'vertical',)
		  f.chart({:defaultSeriesType=>"line"})
		    f.plotOptions({
		        series:{
		            cursor: 'pointer',
		            connectNulls: true,
		             point: {
		                  events: {
		                            click: %| function(){ 
		                                   alert(window.location.hostname + '/guilds/' + this.guild_id + '/recent_activity/' + this.time);
		                          } |.js_code
		                  }
		              }
		          }
		      })
   
		end
		if params[:event] then
			@affected = Array.new
			for log in Log.where("n_date = #{params[:event]}") do
				@affected.push(log.guild_member_id) if not @affected.index(log.guild_member_id)
			end
			@members_grid = initialize_grid(@guild.guild_members.where(id: @affected))
		end
    end

    def update_settings
    	Guild.find(params[:id]).update_attributes(:min_affected => params[:min_aff] , :max_events => params[:max_ev])
    	redirect_to recent_activity_guild_path(params[:id])
    end

  	def edit
  		@guild = Guild.find(params[:id])
	end

	def create
	  	@guild =  Guild.new(guild_params)
	 
	 	if @guild.save
			User.find_by_email(current_user.email).update_attribute(:guild_id , @guild.id)

	 		redirect_to @guild , notice: 'Guild created'
	 	else
	 		render 'new' ,  notice: 'Guild creation fail'
	 	end
	end

	def update
	  @guild = Guild.find(params[:id])
	 
	  if @guild.update(guild_params)
	    redirect_to @guild
	  else
	    render 'edit'
	  end
	end

	def destroy
		@guild = Guild.find(params[:id])
		Item.where(:of_guild_id => params[:id].to_i).destroy_all
		for guild_member in @guild.guild_members do
			guild_member.logs.destroy_all
		end
		@guild.guild_members.destroy_all
		@guild.destroy
		User.find_by_email(current_user.email).update_attribute(:guild_id , nil)
		redirect_to guilds_path , notice: 'Guild deleted successfully.'
	end

	class Net::FTP
	  def puttextcontent(content, remotefile, &block)
	    f = StringIO.new(content)
	    begin
	      storlines("STOR " + remotefile, f, &block)
	    ensure
	      f.close
	    end
	  end
	end


	def upload
		@guild = Guild.find(params[:id])
	end

	def import
		@guild = Guild.find(params[:id])
		strState , c_counter , u_counter , l_counter , i_counter = @guild.import(params)
		if strState == "success" then
			Guild.find(params[:id]).update_attributes(:updated_at => DateTime.now)

			begin
				ftp = Net::FTP.new('31.220.16.113')
				ftp.passive = true
				ftp.login('u292965448', ENV['FTP_PASS'])
				ftp.puttextcontent(params[:json], "/public_html/guild_json_#{params[:id]}.txt")
				ftp.close
			rescue
				redirect_to @guild , notice: "Import successfull: Created #{c_counter.to_s} entries , updated #{u_counter.to_s} entries. Processed #{i_counter} items and #{l_counter} logs. Backup file upload failed."
				return
			end

			redirect_to @guild , notice: "Import successfull: Created #{c_counter.to_s} entries , updated #{u_counter.to_s} entries. Processed #{i_counter} items and #{l_counter} logs. Backup file successfully uploaded."
		elsif strState == "fail" then
			redirect_to upload_guild_path(@guild) , notice: 'Invalid data'
		else
			redirect_to upload_guild_path(@guild) , notice: strState
		end
	end

	def review_changes
		@members_grid = initialize_grid(GuildMember.where("guild_id = #{params[:id]} and edit_flag IS NOT NULL"))
		@guild = Guild.find(params[:id])
	end

	def commit_all
		for member in GuildMember.where("guild_id = #{params[:id]} and edit_flag IS NOT NULL") do
			member.commit(false)
			redirect_to guild_path(params[:id])
		end
		Guild.find(params[:id]).update_json
	end

	def undo_all
		for member in GuildMember.where("guild_id = #{params[:id]} and edit_flag IS NOT NULL") do
			member.destroy
			redirect_to guild_path(params[:id])
		end
	end

	private
		def guild_params
	  		params.require(:guild).permit(:name, :owner, :realm,:mode)
		end
end
