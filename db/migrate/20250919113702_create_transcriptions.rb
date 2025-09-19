class CreateTranscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :transcriptions do |t|
      t.text :raw_text
      t.text :summary
      t.string :status

      t.timestamps
    end
  end
end
