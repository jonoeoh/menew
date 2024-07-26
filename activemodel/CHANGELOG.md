*   Add `:except` option for validations. Grants the ability to _skip_ validations in specified contexts.

    ```ruby
    class User < ApplicationRecord
        #...
        validates :birthday, presence: { except: :admin }
        #...
    end

    user = User.new(attributes except birthday)
    user.save(context: :admin)
    ```

    *Drew Bragg*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activemodel/CHANGELOG.md) for previous changes.
