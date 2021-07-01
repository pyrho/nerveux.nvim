local u = require "nerveux.utils"

describe("When extracting links", function()

  it("should work on the simplest links", function()
    do
      local line = "[[12345]]"
      assert.same({{1, 9, "12345", false}}, u.get_all_link_indices(line))
    end

    do
      local line = "[[1234567890abcdefghijklmnopqrstuvwxyzABCDDE]]"
      assert.same(
          {{1, 46, "1234567890abcdefghijklmnopqrstuvwxyzABCDDE", false}},
          u.get_all_link_indices(line))
    end
  end)

  it("should work when a the link is in the middle of the line", function()
    local line = "ok ca marche [[12345]] salut merci"
    assert.same({{14, 22, "12345", false}}, u.get_all_link_indices(line))
  end)

  it("should work with multiple links on the same line ", function()
    local line = "ok ca marche [[12345]] salut merci [[abcdef123]]"
    assert.same({{14, 22, "12345", false}, {36, 48, "abcdef123", false}},
                u.get_all_link_indices(line))
  end)

  it("should work with folgezettels", function()
    local line = "ok ca marche [[12345]]#"
    assert.same({{14, 23, "12345", true}}, u.get_all_link_indices(line))
  end)

  it("should work with a simple aliases", function()
    do
      local line = "ok ca marche [[12345|alias]]#"
      assert.same({{14, #line, "12345", true}}, u.get_all_link_indices(line))
    end

    do
      local line =
          "ok ca marche [[12345zxcv|alias with spaces wow ! SPACES!@#%]]#"
      assert.same({{14, #line, "12345zxcv", true}}, u.get_all_link_indices(line))
    end
  end)

  it("should work with aliases and folgezettels with aliases", function()
    local line =
        "[[1232sd|this is an alias]] hi this is [[2547ad|HEy!!! ok]]# a link right there"
    assert.same({{1, 27, "1232sd", false}, {40, 60, "2547ad", true}},
                u.get_all_link_indices(line))
  end)

end)
