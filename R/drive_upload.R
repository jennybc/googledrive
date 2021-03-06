#' Upload into a new Drive file
#'
#' Uploads a local file into a new Drive file. To update the content or metadata
#' of an existing Drive file, use [drive_update()]. To upload or update,
#' depending on whether the Drive file already exists, see [drive_put()].
#'
#' @seealso Wraps the `files.create` endpoint:
#'   * <https://developers.google.com/drive/v3/reference/files/create>
#'
#' MIME types that can be converted to native Google formats:
#'    * <https://developers.google.com/drive/v3/web/manage-uploads#importing_to_google_docs_types_wzxhzdk18wzxhzdk19>
#'
#' @template media
#' @template path
#' @templateVar name file
#' @templateVar default If not given or unknown, will default to the "My Drive"
#'   root folder.
#' @template name
#' @templateVar name file
#' @templateVar default Will default to its local name.
#' @param type Character. If `type = NULL`, a MIME type is automatically
#'   determined from the file extension, if possible. If the source file is of a
#'   suitable type, you can request conversion to Google Doc, Sheet or Slides by
#'   setting `type` to `document`, `spreadsheet`, or `presentation`,
#'   respectively. All non-`NULL` values for `type` are pre-processed with
#'   [drive_mime_type()].
#' @template dots-metadata
#' @template overwrite
#' @template verbose
#'
#' @template dribble-return
#' @export
#' @examples
#' \dontrun{
#' ## upload a csv file
#' chicken_csv <- drive_upload(
#'   drive_example("chicken.csv"),
#'   "chicken-upload.csv"
#' )
#'
#' ## or convert it to a Google Sheet
#' chicken_sheet <- drive_upload(
#'   drive_example("chicken.csv"),
#'   name = "chicken-sheet-upload.csv",
#'   type = "spreadsheet"
#' )
#'
#' ## check out the new Sheet!
#' drive_browse(chicken_sheet)
#'
#' ## clean-up
#' drive_find("chicken.*upload") %>% drive_rm()
#'
#' ## Upload a file and, at the same time, star it
#' chicken <- drive_upload(
#'   drive_example("chicken.jpg"),
#'   starred = "true"
#' )
#'
#' ## Is is really starred? YES
#' purrr::pluck(chicken, "drive_resource", 1, "starred")
#'
#' ## Clean up
#' drive_rm(chicken)
#'
#' ## `overwrite = FALSE` errors if something already exists at target filepath
#' ## THIS WILL ERROR!
#' drive_create("name-squatter")
#' drive_upload(
#'   drive_example("chicken.jpg"),
#'   name = "name-squatter",
#'   overwrite = FALSE
#' )
#'
#' ## `overwrite = TRUE` moves the existing item to trash, then proceeds
#' chicken <- drive_upload(
#'   drive_example("chicken.jpg"),
#'   name = "name-squatter",
#'   overwrite = TRUE
#' )
#'
#' ## Clean up
#' drive_rm(chicken)
#'
#' ## Upload to a Team Drive:
#' ##   * your Google account must have Team Drive privileges, obviously
#' ##   * the Team Drive (or Team Drive-hosted folder) MUST be captured as a
#' ##     dribble first and provided via `path`
#' td <- team_drive_get("Marketing")
#' drive_upload("fascinating.csv", path = td)
#' }
drive_upload <- function(media,
                         path = NULL,
                         name = NULL,
                         type = NULL,
                         ...,
                         overwrite = NA,
                         verbose = TRUE) {
  if (!file.exists(media)) {
    stop_glue("\nFile does not exist:\n  * {media}")
  }

  tmp <- rationalize_path_name(path, name)
  path <- tmp$path
  name <- tmp$name

  params <- toCamel(rlang::list2(...))

  # load (path, name) into params
  if (!is.null(path)) {
    path <- as_parent(path)
    params[["parents"]] <- path$id
  }
  params[["name"]] <- name %||% basename(media)

  check_for_overwrite(params[["parents"]], params[["name"]], overwrite)

  params[["fields"]] <- params[["fields"]] %||% "*"
  params[["mimeType"]] <- drive_mime_type(type)
  params[["uploadType"]] <- "multipart"

  request <- request_generate(
    endpoint = "drive.files.create.media",
    params = params
  )

  meta_file <- tempfile()
  on.exit(unlink(meta_file))
  writeLines(jsonlite::toJSON(params), meta_file)
  ## media uploads have unique body situations, so customizing here.
  request$body <- list(
    metadata = httr::upload_file(
      path = meta_file,
      type = "application/json; charset=UTF-8"
    ),
    media = httr::upload_file(path = media)
  )

  response <- request_make(request, encode = "multipart")
  out <- as_dribble(list(gargle::response_process(response)))

  if (verbose) {
    message_glue(
      "\nLocal file:\n  * {media}\n",
      "uploaded into Drive file:\n  * {out$name}: {out$id}\n",
      "with MIME type:\n  * {out$drive_resource[[1]]$mimeType}"
    )
  }
  invisible(out)
}
