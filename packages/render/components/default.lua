local default = {}; default.__index = default

function default.viewport(vr)
	local x, y = vr.x or 0, vr.y or 0
	local w, h = assert(vr.w), assert(vr.h)
	return {
		clear_state = {
			color = 0x303030ff,
			depth = 1,
			stencil = 0,
			clear = "all",
		},
		rect = {
			x = x, y = y,
			w = w, h = h,
		},
	}
end

function default.frustum(w, h)
	w = w or 800
	h = h or 600
	return {
		type = "mat",
		n = 0.1, f = 100000,
		fov = 60, aspect = w / h,
	}
end

function default.ortho_frustum(n, f, l, r, t, b)
	return {
		type = "mat",
		n = n or 0.1, f = f or 100000,
		l = l or -1, r = r or 1,
		t = t or -1, b = b or 1,
		ortho = true,
	}
end

function default.camera(eyepos, viewdir, frustum, camtype)
	return {
		type = camtype or "",
		eyepos = eyepos or {0, 0, 0, 1},
		viewdir = viewdir or {0, 0, 1, 0},
		updir = {0, 1, 0, 0},
		frustum = frustum or util.default_frustum_component(),
	}
end

function default.render_buffer(w, h, format, flags)
	return {
		w = w,
		h = h,
		layers = 1,
		format = format,
		flags = flags,
	}
end

return default