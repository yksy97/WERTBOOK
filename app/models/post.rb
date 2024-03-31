class Post < ApplicationRecord
  # 会員
  belongs_to :customer
  # タックル
  belongs_to :tackle, optional: true
  # コメント
  has_many :post_comments, dependent: :destroy
  # いいね
  has_many :favorites, dependent: :destroy
  # 通知
  has_many :notifications, as: :notifiable, dependent: :destroy
  # 釣り方
  has_many :rig_posts, dependent: :destroy
  has_many :rigs, through: :rig_posts
  attr_accessor :rig_list

  validate :validate_genre_presence
  validates :title, presence: true, length: { maximum: 50 }
  validates :body, presence: true, length: { maximum: 500 }
  validates :location, presence: true


  # 投稿のバリデーション
  def validate_genre_presence
    # 既存の魚種が選択されていない、かつ、新規の魚種が空欄の場合
    if genre_name.blank? && new_genre_name.blank?
      errors.add(:base, '既存の魚種を選択するか、新規の魚種名を入力してください')
    end

    # 新規の魚種は、その名前でジャンルが存在するかチェックし、存在しなければ新規ジャンルで作成
    unless new_genre_name.blank?
      new_genre = Genre.find_or_create_by(name: new_genre_name)
      # 新規の魚種をPostに関連付け
      self.genre_name = new_genre.name 
    end
  end
  
  # 新規の魚種
  attr_accessor :new_genre_name

  # いいね
  def favorited_by?(customer)
    favorites.where(customer_id: customer.id).exists?
  end

  # 画像
  has_one_attached :image

  # no_image画像 
  def get_image
    if image.attached?
      image
    else
      'no_image.jpg'
    end
  end

  # 釣り方
  def save_rigs(rigs)
    rig_list = rigs.split(/[[:blank:]]+/)
    current_rigs = self.rigs.pluck(:name)

    old_rigs = current_rigs - rig_list
    new_rigs = rig_list - current_rigs
    old_rigs.each do |old|
      self.rigs.delete Rig.find_by(name: old)
  end

    new_rigs.each do |new|
      new_post_rig = Rig.find_or_create_by(name: new)
      self.rigs << new_post_rig
    end
  end

  after_find :rigs_to_rig_list
  def rigs_to_rig_list
    if self.rigs && self.rigs.any?
      self.rig_list = self.rigs.map{|o| o.name }.join(" ")
    end
  end
  before_update :update_rigs
  def update_rigs
    save_rigs(self.rig_list)
  end

  after_create do
    customer.followers.each do |follower|
      notifications.create(customer_id: follower.id)
    end
  end  

  # 検索機能
  def self.ransackable_attributes(auth_object = nil)
    ["body", "genre_name"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["post_comments", "rig_posts", "rigs", "tackle"]
  end
end


#勉強メモ
# ５行目の「optional:ture」は、投稿時にタックルの記載が必須ではないことを意味する



# １１行目の「as: :notifiable」は、ポリモーフィック関連。
# -ポリモーフィック関連とは、あるモデルが複数の異なるモデルと関連付けされるような関係（多様性）。
# -Railsでは、asオプションを使ってポリモーフィック関連を実装する。

# -ポリモーフィック関連によって、「Notification」モデルは、「Post」モデルだけではなく、通知が可能な他の任意のモデル（ex: 「Comment」モデルや「Favorite」モデルなど）とも関連付けることができる。
# -「Notification」モデルと通知されるモデル（「Post」モデル）は１：多の関係になり、通知対象が削除された場合は通知自体が削除される。＝１つの通知は１つの投稿に関連づけられるが、投稿は複数の通知を持つことができる。
# -１つの通知は１つの投稿に関連づけられるが、投稿は複数の通知を持つことができる。

# -上記をコードにすると、
# --「Notification」モデル　：　belongs_to :notifiable, polymorphic: true
# --「Post」モデル　：　has_many :notifications, as: :notifiable, dependent: :destroy

# 補足として、ポリモーフィック関連はデータモデルの設計に柔軟であるが、クエリが複雑になり、アプリのパフォーマンスに影響するので注意する。



# 17行目の「validate :validate_genre_presence」はカスタムバリデーションメソッド。投稿時に新規または既存の魚種を必ず選択しなければならない。
# -24行目の「validate_genre_presence」メソッドで行っている処理は２つ。
# --①既存と新規の魚種のチェック
# ---「genre_name.blank?」かつ「new_genre_name.blank?」の場合に、エラーメッセージを表示すること。

# --②新規の魚種の処理
# ---新規の魚種のフォームが空ではない（unless）場合に、「Genre.find_or_create_by(name: new_genre_name)」で入力された魚種が「Genre」モデルに存在するか確認して、存在しなければ新規の魚種として追加する。

# 補足として、Railsの「find_or_create_by」メソッドについて
# -指定された条件に一致するレコードをデータベースから検索し、一致するレコードが「存在する場合」は、そのオブジェクトを返す。一方で、「存在しない場合」は、新しいレコードを作成して保存し、その新しいオブジェクトを返す。
# --「new_genre = Genre.find_or_create_by(name: new_genre_name)」では、「name」が「new_genre_name」に一致するGenreオブジェクトをデータベースから探す。
# --例：新規の魚種に「マグロ」と入力されていたら、「マグロ」というGenreオブジェクトをデータベースに存在していないか探す。
# --もし「マグロ」が存在していれば、マグロを左辺の「new_genre」に代入する。存在しなければ、「name」属性が「マグロ」という新しい魚種をデータベースに保存後、「new_genre」に代入する。

# Railsの「find_or_create_by」メソッドの利点
# -①効率的：存在の確認と作成の処理を１行で記述できる。
# -②DRYの原則：「検索するたびに存在の確認して作成する」というような処理を繰り返し書くことを避けることができる。
# -③一貫性：新しいレコード（PFでいう新規の魚種）が必要な場合に、モデルのバリデーションを利用して、一貫した処理を行うことで、データの整合性を保つことができる。



# 39行目の「attr_accessor :new_genre_name」はRubyのメソッドであり、仮想属性を定義するために使用される。
# -「仮想属性」は、ゲッター（読み取りメソッド）とセッター（書き込みメソッド）を自動的に定義し、インスタンス変数に対して読み書きを可能にする。

# ゲッターとセッターとは、オブジェクト指向プログラミングにおいて、オブジェクトのプロパティ（属性）へのアクセス方法を提供するメソッド

# -「ゲッターとセッターが自動定義される」ことにより、以下のような操作が可能になる。
# --post = Post.new     ：Postオブジェクトを作成
# --post.new_genre_name = "Fish"  ：セッターメソッドを使ってnew_genre_name属性に値（Fish）を設定
# --puts post.new_genre_name      ：ゲッターメソッドを使ってnew_genre_name属性の値を取得して表示

# -「attr_accessor :new_genre_name」を使用して、Postモデルに仮想属性new_genre_nameを定義することで、新規に提案された魚種名を一時的に保持できる。
# -この仮想属性は、ユーザーからの入力を受け取り、その後の処理（例えば、Genreモデルへの新規魚種の保存）に利用される。しかし、このデータはPostモデルのデータベーステーブルには保存されない。
# -一方で、Genreモデルに新規魚種を保存する場合は、直接name属性に魚種名を設定し、モデルをデータベースに保存する。この場合、attr_accessorを使用する必要はない。
# したがって、フォームから受け取ったデータをモデルの属性として一時的に扱いたいが、そのデータをデータベースに保存する必要がない場合に便利。

# 注意したいことは、new_genre = Genre.find_or_create_by(name: new_genre_name)における(name: new_genre_name)とattr_accessor :new_genre_nameにおけるnew_genre_nameは、同じnew_genre_nameを参照していますが、使われ方に違いがある。
# -attr_accessor :new_genre_nameで定義されたnew_genre_name仮想属性は、ユーザーからの入力を一時的にモデル内で保持するために使用され、
# -new_genre = Genre.find_or_create_by(name: new_genre_name)の行でその値が使用されて、新規のジャンルがデータベースに存在するかどうかをチェック（または新しいものを作成）するという流れになる。
# つまり、前者のnew_genre_nameは仮想属性として、投稿フォームにユーザーが入力した新規の魚種を一時的に保持するためにPostモデルで使用され、後者のnew_genre_nameはGenreモデルのデータベース内で同じ魚種が存在するか確認して、存在しない場合には新しい魚種として保存する。



