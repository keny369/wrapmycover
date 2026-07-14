class CreateActiveSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :active_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :ip
      t.string :user_agent
      t.datetime :last_seen_at

      t.timestamps
    end
    add_index :active_sessions, :token_digest, unique: true
  end
end
