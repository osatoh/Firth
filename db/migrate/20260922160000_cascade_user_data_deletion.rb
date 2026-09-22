# Lets the database remove a user's feeds, articles and summaries in a few
# statements when the account is deleted (spec 2.3.7), instead of Rails
# loading and destroying every row.
class CascadeUserDataDeletion < ActiveRecord::Migration[8.1]
  def change
    [ %i[feeds users], %i[articles feeds], %i[summaries articles] ].each do |from, to|
      remove_foreign_key from, to
      add_foreign_key from, to, on_delete: :cascade
    end
  end
end
