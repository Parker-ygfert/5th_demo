document.addEventListener("turbolinks:load", () => {
  if(document.querySelector(".fa-shopping-cart")) {
    getCartItems();
  }
  
  if(document.querySelector(".add-to-cart-btn")) {
    const addCartBtn = document.querySelector(".add-to-cart-btn");

    addCartBtn.addEventListener("click", e => {
      if (e.target.classList.contains("add-to-cart-btn")) {
        // 加入 setTimeout 避免後端資料還沒寫入，前端就先去抓資料
        setTimeout(() => { getCartItems(); }, 500);
      }
    })
  }

  function getCartItems() {
    fetch("http://localhost:3000/cart.json")
      .then(response => response.json())
      .then(cartItems => {
        let cartBubble = document.querySelector(".cart-bubble")

        if (cartItems.length === 0) {
          cartBubble.style.opacity = "0";
        } else {
          let cartCount = cartItems[0][1].reduce((sum, item) => {
            return sum += item.quantity
          }, 0).toString();
          
          cartBubble.style.opacity = "1";
          cartBubble.textContent = cartCount;
        }
      });
  }
});
