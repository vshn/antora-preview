group :documentation do
    # Rebuild documentation when modifying files
    guard :shell do
        watch(/(.*).adoc/) do
            `antora --cache-dir=/preview/public/.cache/antora /preview/playbook.yml`
        end
    end

    # Refresh browser when folder with HTML files changes
    guard :livereload do
        watch(/(.*).html/)
    end
end
