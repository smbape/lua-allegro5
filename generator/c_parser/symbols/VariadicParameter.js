class VariadicParameter {
    constructor({
        comma,
        variadic
    }, loc) {
        this.comma = comma;
        this.variadic = variadic;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.comma.visit(cb, parents);
        this.variadic.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.VariadicParameter = VariadicParameter;
