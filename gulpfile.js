var gulp = require('gulp');
var coffee = require('gulp-coffee');
var concat = require('gulp-concat');
var uglify = require('gulp-uglify');
var sourcemaps = require('gulp-sourcemaps');
var browserify = require('browserify');
var source = require('vinyl-source-stream');
var buffer = require('vinyl-buffer');
var webserver = require('gulp-webserver');

gulp.task('scripts', function () {
    return browserify({entries: ['./src/hl7mapper.coffee'], extensions: ['.coffee']})
        .transform('coffeeify')
        .bundle()
        .pipe(source('app.js'))
        // .pipe(buffer())
        // .pipe(uglify())
        .pipe(gulp.dest('./dist'))
});

gulp.task('server', function() {
    gulp.src('./dist')
        .pipe(webserver({
            livereload: false,
            directoryListing: false,
            open: false
        }));
});

// Rerun the task when a file changes
gulp.task('watch', function() {
    gulp.watch(paths.scripts, ['scripts']);
});

// The default task (called when you run `gulp` from cli)
gulp.task('default', ['watch', 'scripts']);
