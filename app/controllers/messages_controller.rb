class MessagesController < BaseController
  before_action :find_user
  before_action :login_required
  before_action :require_ownership_or_moderator, :except => [:auto_complete_for_username]

  skip_before_action :verify_authenticity_token, :only => [:auto_complete_for_username]

  def auto_complete_for_username
    @usernames = User.active.where.not(login: @user.login).pluck(:login)
    respond_to do |format|
      format.json {render :inline => @usernames.to_json}
    end
  end

  def index
    if params[:mailbox] == "sent"
      @messages = @user.sent_messages.page(params[:page]).per(20)
    else
      @messages = @user.message_threads_as_recipient.order('updated_at DESC').page(params[:page]).per(20)
    end
  end

  def show
    @message = Message.read(params[:id], @user)
    @message_thread = MessageThread.for(@message, (admin? ? @message.recipient : current_user ))
    @reply = Message.new_reply(@user, @message_thread, params)
  end

  def new
    if params[:reply_to]
      in_reply_to = Message.find_by_id(params[:reply_to])
      message_thread = MessageThread.for(in_reply_to, current_user)
    end
    @message = Message.new_reply(@user, message_thread, params)
  end

  def create
    messages = []

    if params.require(:message)[:to].blank?
      # If 'to' field is empty, call validations to catch other errors
      @message = Message.new(message_params)
      @message.valid?
      render :action => :new and return
    else
      @message = Message.new(message_params)
      @message.recipient= User.where('lower(login) = ?', params.require(:message)[:to].strip.downcase).first
      @message.sender = @user
      unless @message.valid?
        render :action => :new and return
      else
        @message.save!
      end
      flash[:notice] = :message_sent.l
      redirect_to user_messages_path(@user) and return
    end
  end

  def delete_selected
    if request.post?
      if params[:delete]
        params[:delete].each { |id|
          @message = Message.where("messages.id = ? AND (sender_id = ? OR recipient_id = ?)", id, @user, @user).first
          @message.mark_deleted(@user) unless @message.nil?
        }
        flash[:notice] = :messages_deleted.l
      end
      redirect_to user_messages_path(@user)
    end
  end

  def delete_message_threads
    if request.post?
      if params[:delete]
        params[:delete].each { |id|
          message_thread = MessageThread.find_by_id_and_recipient_id(id, @user.id)
          message_thread.destroy if message_thread
        }
        flash[:notice] = :messages_deleted.l
      end
      redirect_to user_messages_path(@user)
    end

  end

  private
    def find_user
      @user = User.find(params[:user_id])
    end

    def require_ownership_or_moderator
      unless admin? || moderator? || (@user && (@user.eql?(current_user)))
        redirect_to :controller => 'sessions', :action => 'new' and return false
      end
      return @user
    end

  def message_params
    params.require(:message).permit(:to, :subject, :body,  :recipient_id, :sender_id, :parent_id)
  end
end
