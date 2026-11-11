-- Made by lunatype from Ordaen/module.luna: change the source, not this file.
local R = LunaType
local __class, __inherit = R.class, R.inherit
local M = {}
R.addon("Ordaen")["module"] = M
local Component, Entry, Module

Component = __class({})

Entry = __class({})

Module = __class({})
__inherit(Module, { Component })

M.Component = Component
M.Entry = Entry
M.Module = Module
