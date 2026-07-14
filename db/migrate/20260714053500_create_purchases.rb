class CreatePurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :purchases do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :book_title, null: false
      t.string  :stripe_checkout_session_id, null: false
      t.string  :stripe_payment_intent_id
      t.integer :amount_cents
      t.string  :currency, default: "usd", null: false
      t.string  :status, default: "pending", null: false
      t.datetime :paid_at

      t.timestamps
    end
    add_index :purchases, :stripe_checkout_session_id, unique: true
    add_index :purchases, [ :user_id, :status ]
  end
end
