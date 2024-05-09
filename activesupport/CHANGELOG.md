*   Adds `assert_error`, `assert_no_error`, `assert_valid` and `assert_not_valid` to ensure a model has the right validations
    ```ruby
    assert_error :name, :blank, :user
    assert_no_error :name, :blank, :user
    assert_valid :name, :blank, :user
    assert_not_valid :name, :blank, :user
    ```

    *Daniela Velasquez*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activesupport/CHANGELOG.md) for previous changes.
