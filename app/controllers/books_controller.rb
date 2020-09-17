class BooksController < ApplicationController  
  before_action :authenticate_user!, only: [:new, :create, :edit, :update, :editor_new, :editor_edit]
  before_action :find_book, except: [:index, :new, :create]
  require'aws-sdk-s3'
  def index
    @books = Book.published_books
  end
  
  def show
    require "open-uri"
    # md = open(@book.md_url).read

    # markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, filter_html: false, autolink: true, tables: true)
    # @md = markdown.render(md)
  end

  def new
    @book = Book.new
  end

  def create
    @book = Book.new(book_params)
    @book.authors << current_user
    
    # 把 cover 切出 大中小 三個尺寸
    @book.cover_derivatives! if @book.cover_data?

    if @book.save
      if @book.md_data
        @book.update(publish_state: "on-shelf")
        redirect_to pricing_book_path(@book)
      else
        # 在 s3 做出書的資料夾，chapter1.md，與 structure.json(存章節結構)
        book_start(@book.title)
        redirect_to dash_board_books_path
        # redirect_to editor_new_book_path(@book)
      end
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @book.update(book_params)
      redirect_to pricing_book_path(@book)
    else
      render :edit
    end
  end

  # 設定書本價格
  def pricing
  end
  
  def publish
    @book.update(book_params)
    @book.update(publish_state: "on-shelf")
    
    redirect_to @book, notice: "書籍已上架囉～"
  end

  # 線上編輯 action
  def editor_new

  end

  def editor_create
    @book = Book.find(params[:id])
  end

  def editor_edit
    @book = Book.find(params[:id])
  end

  def editor_update
  
  end

  def add_chapter
    if params[:chapter] != ""  
      @book = Book.find(params[:id])
      # 後來考慮把打 s3 做成一個 service
      # storage = BookStorage.find(book.id)
      # # render error if not find storage
      # if storage.add_chapter("name")
      #   # success
      # else
      #   # errors
      #   storage.errors
      
      # 取到結構json檔資料
      s3 = Aws::S3::Client.new
      object = s3.get_object(bucket: ENV['bucket'], key:"store/book/#{@book.title}/structure.json")    
      structure_json = object.body.read
      # 將新增的章節加入結構中
      structure_json = JSON.parse(structure_json)
      chapter = { "#{params[:chapter]}": []}
      structure_json.push(chapter)     
      structure_json = structure_json.to_json
      
      s3 = Aws::S3::Resource.new
      bucket = s3.bucket(ENV['bucket'])
      structure = bucket.object("store/book/#{@book.title}/structure.json")
      structure.put(body: structure_json)
      # 將新的結構存到 structure.json檔案
      chapter = bucket.object("store/book/#{@book.title}/#{params[:chapter]}.md")
      chapter.put(body:'# New Chapter')
      # 做出章節
    end
  end

  def add_session
    @book = Book.find(params[:id])
    
    if params[:session] != ""
      # 取到結構json檔資料
      s3 = Aws::S3::Client.new
      object = s3.get_object(bucket: ENV['bucket'], key:"store/book/#{@book.title}/structure.json")    
      structure_json = object.body.read
      # 將新增的 session 加入結構中
      structure_json = JSON.parse(structure_json)
      structure_json[params[:order].to_i][params[:chapter]].push(params[:session])
      structure_json = structure_json.to_json
      
      s3 = Aws::S3::Resource.new
      bucket = s3.bucket(ENV['bucket'])
      structure = bucket.object("store/book/#{@book.title}/structure.json")
      structure.put(body: structure_json)
      # 將新的結構存到 structure.json檔案
      chapter = bucket.object("store/book/#{@book.title}/#{params[:session]}.md")
      chapter.put(body:'# New Session')
      # 做出 session 檔案
    end
  end
  

  private
  def book_params
    params.require(:book).permit(:cover, :title, :about, :price, :catalog, :completeness, :md)
  end

  def find_book
    @book = Book.find_by(id: params[:id])
  end

  def book_start(title)
    s3 = Aws::S3::Resource.new
    bucket = s3.bucket(ENV['bucket'])
    structure = bucket.object("store/book/#{title}/structure.json")
    a = [Chapter_1:[]]
    a = a.to_json
    structure.put(body: a )
    chapter = bucket.object("store/book/#{title}/Chapter_1.md")
    chapter.put(body:'# Chapter_1')
  end
  
end