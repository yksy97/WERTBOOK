class Public::PostCommentsController < ApplicationController
  before_action :set_post, only: [:create, :update, :destroy]
  before_action :ensure_correct_customer, only: [:update, :destroy]

  def create
    @comment = current_user.post_comments.new(post_comment_params.merge(post_id: @post.id))
    if @comment.save
      redirect_to post_path(@post), notice: 'コメントが投稿されました'
    else
      redirect_to post_path(@post), alert: 'コメントの投稿に失敗しました'
    end
  end

  def update
    @comment = @post.post_comments.find(params[:id])
    respond_to do |format|
      if @comment.update(post_comment_params)
        format.js { flash.now[:notice] = 'コメントが更新されました' }
      else
        format.js { flash.now[:alert] = 'コメントの更新に失敗しました' }
      end
    end
  end

  def destroy
    @comment = @post.post_comments.find(params[:id])
    respond_to do |format|
      if @comment.destroy
        format.js
      end
    end
  end

  private

  def set_post
    @post = Post.find(params[:post_id])
  end
  
  def post_params
  params.require(:post).permit(:title, :body, :image)
end

  def post_comment_params
    params.require(:post_comment).permit(:comment)
  end

  def ensure_correct_customer
    @comment = @post.post_comments.find(params[:id])
    unless @comment.customer == current_customer
      redirect_to post_path(@post), alert: "権限がありません"
    end
  end
end
