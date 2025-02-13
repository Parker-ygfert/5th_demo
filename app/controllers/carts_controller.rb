class CartsController < ApplicationController

  def add
    cart_price = params[:cart_price][1..-1].to_f
    
    current_cart.add_item(params[:id], cart_price) 
    session[Cart::SessionKey] = current_cart.serialize
  end

  def show
    respond_to do |format|
      format.html
      format.json { @cart = session[Cart::SessionKey] }
    end
  end


  def update
    index = params[:index].to_i
    price = params[:price][1..-1].to_f

    current_cart.update_price(current_cart.items[index], price)
    session[Cart::SessionKey] = current_cart.serialize
  end
  

  def delete
    cart = current_cart.items
    @items = cart.select.with_index { |item, index|
      item if index != params[:index].to_i
    }
    current_cart.delete_item(@items)
    session[Cart::SessionKey] = current_cart.serialize

    flash[:notice] = "成功移出購物車"
  end

  def destroy
    session[Cart::SessionKey] = nil
    redirect_to :cart, notice: "購物車已清空"
  end


  def payment
    if current_cart.empty?
      redirect_to :books, notice: "購物車空空"
    else
      if user_signed_in?
        @token = gateway.client_token.generate
      else
        redirect_to new_user_session_path
      end
    end
  end

  def checkout
    result = gateway.transaction.sale(
      amount: current_cart.total_price,
      payment_method_nonce: params[:nonce],
      options: {
        submit_for_settlement: true
      }
    )

    if result.success?
      # 成功付款建立訂單
      create_order(current_user, result.transaction.id)

      current_cart.items.each do |item|
        current_user.bought_books << Book.find_by(id: item.book_id)
      end
             
      session[Cart::SessionKey] = nil
      redirect_to root_path, notice: "付款成功"
    else
      redirect_to root_path, notice: "付款發生錯誤"
    end
  end


  def refund
    transaction = gateway.transaction.find(params[:trans_id])
    order = current_user.orders.find_by(uuid: params[:uuid])

    if transaction.status == "settled" or transaction.status == "settling"
      refund = gateway.transaction.refund(transaction.id)
    elsif transaction.status == "submitted_for_settlement"
      refund = gateway.transaction.void(transaction.id)
    else
      redirect_to purchases_path, notice: "退款發生錯誤，請聯絡客服人員"
    end

    if refund.success?
      order.state = "refund"
      order.order_items.each do |item|
        BookUser.find_by(user_id: current_user, book_id: item.book).destroy
        current_user.bought_books.destroy(item.book)
      end
      order.destroy

      redirect_to purchases_path, notice: "已成功申請退款"
    else
      redirect_to purchases_path, notice: "退款失敗，請重新申請"
    end
  end



  private
  def gateway
    Braintree::Gateway.new(
      environment: :sandbox, 
      merchant_id: ENV["merchant_id"],
      public_key: ENV["public_key"],
      private_key: ENV["private_key"],
    )
  end

  def create_order(user, id)
    order = user.orders.create(
      payment_term: "credit card",
      state: "success",
      total: "#{current_cart.total_price}",
      transaction_id: id
    )
    
    # 建立訂單項目
    create_order_items(order)
  end

  def create_order_items(order)
    current_cart.items.each do |item|
      order.order_items.create(
        book_id: item.book_id,
        price: item.cart_price,
        amount: 1
      )
    end
  end
end
