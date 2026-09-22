class AddSettingsToUsers < ActiveRecord::Migration[8.1]
  def change
    # Encrypted with Active Record Encryption, so the column holds ciphertext.
    add_column :users, :anthropic_api_key, :text
    add_column :users, :summary_language, :string, null: false, default: "ja"
  end
end
