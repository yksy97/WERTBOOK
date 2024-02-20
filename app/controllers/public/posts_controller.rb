class Public::PostsController < ApplicationController
  before_action :authenticate_customer!
  before_action :ensure_correct_customer, only: [:edit, :update, :destroy]

  def new
    @post = Post.new
    @genres = Genre.order(:name)
    @tackles = Tackle.all
  end
  
  def index
    if params[:rig_id]
      @posts = Rig.find(params[:rig_id]).posts.includes(:customer, :genre).page(params[:page]).per(8).order(created_at: :desc)
    elsif params[:location]
      @posts = Post.where(location: params[:location]).includes(:customer, :genre).page(params[:page]).per(8).order(created_at: :desc)
    else
      @posts = Post.includes(:customer, :genre).page(params[:page]).per(8).order(created_at: :desc)
    end
    @post = Post.new
    @genres = Genre.order(:name)
    @tackles = Tackle.all
  end

  def show
    @post = Post.find(params[:id])
    @customer = @post.customer
    @post_comment = PostComment.new
    @post_comments = @post.post_comments.order(created_at: :desc)
  end

  def create
    @post = current_customer.posts.build(post_params)

    if params[:post][:new_genre_name].present?
      genre = Genre.find_or_create_by(name: params[:post][:new_genre_name])
      @post.genre_id = genre.id
    end

    if @post.save
      @post.save_rigs(params[:post][:rig_list])
      redirect_to posts_path, notice: "投稿が完了しました"
    else
      @posts = Post.includes(:customer, :genre).order(created_at: :desc)
      @my_posts = current_customer.posts.order(created_at: :desc)
      @genres = Genre.order(:name)
      @tackles = Tackle.all
      render :index
    end
  end

  def genre
    genre = Genre.find(params[:id])
    @posts = genre.posts
  end

  def edit
    @post = Post.find(params[:id])
  end

  def update
    @post = Post.find(params[:id])
    if @post.update(post_params)
      redirect_to post_path(@post), notice: "投稿が更新されました"
    else
      render :edit
    end
  end
  
  def tackle_selection
  @post = Post.find(params[:id])
  if @post.update(tackle_id: params[:post][:tackle_id])
    redirect_to @post, notice: '登録したタックルが適用されました'
  else
    render :edit, alert: '登録したタックルの適用に失敗しました'
  end
  end

  def destroy
    @post = Post.find(params[:id])
    @post.destroy
    redirect_to posts_path, notice: "投稿が削除されました"
  end

  private

  def post_params
    params.require(:post).permit(:body, :image, :genre_id, :location, :tackle_id, :rig_list)
  end

  def ensure_correct_customer
    @post = Post.find(params[:id])
    unless @post.customer == current_customer
      redirect_to posts_path, alert: '権限がありません。'
    end
  end
end
