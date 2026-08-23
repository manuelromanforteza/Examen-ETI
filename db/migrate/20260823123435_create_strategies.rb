class CreateStrategies < ActiveRecord::Migration[8.1]
  def change
    create_table :strategies do |t|
      t.string :key
      t.string :name
      t.text :description
      t.text :pros
      t.text :cons

      t.timestamps
    end
  end
end
