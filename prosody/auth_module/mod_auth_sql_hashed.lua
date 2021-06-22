-- Simple SQL Authentication module for Prosody IM
-- Copyright (C) 2011 Tomasz Sterna <tomek@xiaoka.com>
-- Copyright (C) 2011 Waqas Hussain <waqas20@gmail.com>
--

local usermanager = require "core.usermanager";
local log = require "util.logger".init("auth_sql");
local new_sasl = require "util.sasl".new;
local DBI = require "DBI"

local random = require "util.random";
local pbkdf2_hmac_sha256 = require "util.hashes".pbkdf2_hmac_sha256;
local base64 = require "util.encodings".base64;
local default_iterations = 320000;

local connection;
local params = module:get_option("auth_sql", module:get_option("sql"));

local resolve_relative_path = require "core.configmanager".resolve_relative_path;

local function test_connection()
	if not connection then return nil; end
	if connection:ping() then
		return true;
	else
		module:log("debug", "Database connection closed");
		connection = nil;
	end
end
local function connect()
	if not test_connection() then
		prosody.unlock_globals();
		local dbh, err = DBI.Connect(
			params.driver, params.database,
			params.username, params.password,
			params.host, params.port
		);
		prosody.lock_globals();
		if not dbh then
			module:log("debug", "Database connection failed: %s", tostring(err));
			return nil, err;
		end
		module:log("debug", "Successfully connected to database");
		dbh:autocommit(true); -- don't run in transaction
		connection = dbh;
		return connection;
	end
end

do -- process options to get a db connection
	params = params or { driver = "SQLite3" };

	if params.driver == "SQLite3" then
		params.database = resolve_relative_path(prosody.paths.data or ".", params.database or "prosody.sqlite");
	end

	assert(params.driver and params.database, "Both the SQL driver and the database need to be specified");

	assert(connect());
end

local function getsql(sql, ...)
	if params.driver == "PostgreSQL" then
		sql = sql:gsub("`", "\"");
	end
	if not test_connection() then connect(); end
	-- do prepared statement stuff
	local stmt, err = connection:prepare(sql);
	if not stmt and not test_connection() then error("connection failed"); end
	if not stmt then module:log("error", "QUERY FAILED: %s %s", err, debug.traceback()); return nil, err; end
	-- run query
	local ok, err = stmt:execute(...);
	if not ok and not test_connection() then error("connection failed"); end
	if not ok then return nil, err; end

	return stmt;
end

local function get_password(username)
	local stmt, err = getsql("SELECT `password`,`is_active` FROM `auth_user` WHERE `username`=?", username);
	if stmt then
		for row in stmt:rows(true) do
			return row.password, row.is_active;
		end
	end
end


provider = {};

function provider.test_password(username, password)
	module:log("debug", "test_password for username: %s", username);
	local stored_password, is_active = get_password(username);
	
	if stored_password == nil or string.len(stored_password) == 0 then
		-- do some word to mitigate timing attacks
		local not_a_password = "pbkdf2_sha256$320000$vygRarphSTOn$K9v4nIlt5UOyptTuFxGX63YNsaMKPm/Hb/umyB8A86I=";
		local alg, iterations, salt, stored_hash = string.match(not_a_password, "^(.+)%$(.+)%$(.+)%$(.+)$");
		local calculated_hash = pbkdf2_hmac_sha256(password, salt, iterations);
		local hash_base64 = base64.encode(calculated_hash);
		return nil, "Auth failed. Provided password is incorrect.";
	end

	local alg, iterations, salt, stored_hash = string.match(stored_password, "^(.+)%$(.+)%$(.+)%$(.+)$");
	
	if iterations == nil or salt == nil or string.len(salt) == 0 then
		module:log("error", "password in wrong format for username: %s", username);
		return nil, "Auth failed. Stored salt and iteration count information is not complete.";
	end

	local calculated_hash = pbkdf2_hmac_sha256(password, salt, iterations);
	local hash_base64 = base64.encode(calculated_hash);

	if hash_base64 == stored_hash and is_active == 1 then
		module:log("debug", "test_password true for username: %s", username);
		return true;
	else
		module:log("debug", "test_password false for username: %s", username);
		return nil, "Auth failed. Invalid username, password, or password hash information.";
	end
end

function provider.get_password(username)
	module:log("debug", "get_password for username: %s", username);
	return get_password(username);
end

function provider.set_password(username, password)
	return nil, "Setting password is not supported.";
end

function provider.user_exists(username)
	if get_password(username) and true then
		module:log("debug", "user_exists true for username: %s", username);
		return true;
	else
		module:log("debug", "user_exists false for username: %s", username);
		return false;
	end
end

function provider.create_user(username, password)
	return nil, "Account creation/modification not supported.";
end

function provider.get_sasl_handler()
	local profile = {
		plain_test = function(sasl, username, password, realm)
			return usermanager.test_password(username, realm, password), true;
			-- return provider.test_password(username, password), true;
		end
	};
	return new_sasl(module.host, profile);
end

function provider.users()
	local stmt, err = getsql("SELECT `username` FROM `auth_user`", module.host);
	if stmt then
		local next, state = stmt:rows(true)
		return function()
			for row in next, state do
				return row.username;
			end
		end
	end
	return stmt, err;
end


module:provides("auth", provider);
