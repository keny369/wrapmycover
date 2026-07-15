class AddBookKeyAndFingerprintToPurchases < ActiveRecord::Migration[8.1]
  def change
    # book_key: a per-project id minted by the editor, so a purchase unlocks one
    # specific project. content_fingerprint: bound on the first authorized
    # export, so the purchase unlocks re-exports of that same cover only.
    add_column :purchases, :book_key, :string
    add_column :purchases, :content_fingerprint, :string
    add_index :purchases, [ :user_id, :book_key ]
  end
end
