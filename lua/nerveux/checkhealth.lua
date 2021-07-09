local M = {}
local Path = require 'plenary.path'
local Job = require 'plenary.job'

local nerveux_config = require "nerveux.config"

local report_error = vim.fn['health#report_error']
local report_ok = vim.fn['health#report_ok']

local function is_neuron_cmd_ok()
  vim.fn['health#report_info']('Checking neuron binary...')

  local is_executable = vim.fn.executable(nerveux_config.neuron_cmd) == 1
  local path_exists = Path:new(nerveux_config.neuron_cmd):exists()

  return is_executable or path_exists
end

local function is_correct_neuron_version()
  local version_string = Job:new({
    command = nerveux_config.neuron_cmd,
    args = {'--version'}
  }):sync()
  local major, minor = unpack(vim.split(version_string[1], '.', true))

  return {tonumber(major) == 1 and tonumber(minor) >= 9, version_string[1]}
end

local function is_valid_zettelkasten_dir()
  return Path:new(string.format([[%s/neuron.dhall]], nerveux_config.neuron_dir))
             :exists()
end

M.checks = function()
  vim.fn['health#report_start']('sanity checks')
  if not is_neuron_cmd_ok() then
    report_error(string.format([[ `%s` does not exist or is not executable ]],
                               nerveux_config.neuron_cmd),
                 "Make sure `neuron_cmd` is correct")
    return
  else
    report_ok 'neuron executable exists'
  end

  local version_is_correct, error_detail = unpack(is_correct_neuron_version())
  if not version_is_correct then
    report_error(
        string.format([[ Version `%s` is not supported ]], error_detail),
        "Update neuron to version 1.9.x at least")
    return
  else
    report_ok 'neuron version is >= 1.9.0 (neuron v2)'
  end

  if not is_valid_zettelkasten_dir() then
    report_error(
        string.format([[%s/neuron.dhall]], nerveux_config.neuron_dir) ..
            " is not a valid directory",
        "Set the proper directory via `neuron_dir` or change the current working directory")
  else
    report_ok '`neuron_dir` is a valid neuron directory'
  end

end

dump()
return M
