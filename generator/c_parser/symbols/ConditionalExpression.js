class ConditionalExpression {
    constructor({
        condition,
        ternary,
        truthy,
        colon,
        falsy
    }, loc) {
        this.condition = condition;
        this.ternary = ternary;
        this.truthy = truthy;
        this.colon = colon;
        this.falsy = falsy;
        this.loc = loc;
    }

    visit(cb, parents = []) {
        parents.push(this);

        this.ternary.visit(cb, parents);
        this.condition.visit(cb, parents);
        this.truthy.visit(cb, parents);
        this.colon.visit(cb, parents);
        this.falsy.visit(cb, parents);

        parents.pop();
        cb(this, parents);
    }
}

exports.ConditionalExpression = ConditionalExpression;
