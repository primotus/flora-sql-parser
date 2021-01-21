
const scanDelete = (o) => {
    if (Array.isArray(o)) {
        o.map(b => scanDelete(b));
        return;
    }
    if (o && typeof (o) === "object") {
        if(o.position) delete o.position;
        Object.keys(o).map(k => {
            scanDelete(o[k])
        });
    }
    // if (!expr) return
    // if (Array.isArray(expr)) {
    //     expr.map(b => scanDelete(b));
    //     return;
    // }
    // if (expr.position) {
    //     delete expr.position;
    // }
    // if (expr.expr) scanDelete(expr.expr)
    // if (expr.args) scanDelete(expr.args)
    // if (expr.value) scanDelete(expr.value)
    // if (expr.left) scanDelete(expr.left)
    // if (expr.right) scanDelete(expr.right)
}
function skiploc(a) {
    // if (a && a.indexOf && a.indexOf('*') >= 0) return a;
    scanDelete(a)
    return a;
};
module.exports = { skiploc };
