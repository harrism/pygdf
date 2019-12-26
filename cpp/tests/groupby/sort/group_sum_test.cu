/*
 * Copyright (c) 2019, NVIDIA CORPORATION.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <tests/utilities/base_fixture.hpp>
#include <tests/utilities/column_wrapper.hpp>
#include <tests/utilities/table_utilities.hpp>
#include <tests/utilities/column_utilities.hpp>
#include <tests/utilities/type_lists.hpp>

#include <cudf/groupby.hpp>
#include <cudf/detail/aggregation.hpp>
#include <cudf/table/table.hpp>

namespace cudf {
namespace test {

void run_test(column_view const& keys,
              column_view const& values,
              column_view const& expect_keys,
              column_view const& expect_vals,
              std::unique_ptr<experimental::aggregation>&& agg)
{
    std::vector<cudf::experimental::groupby::aggregation_request> requests;
    requests.emplace_back(
        cudf::experimental::groupby::aggregation_request());
    requests[0].values = values;
    
    requests[0].aggregations.push_back(std::move(agg));

    cudf::experimental::groupby::groupby gb_obj(table_view({keys}));

    auto result = gb_obj.aggregate(requests);
    expect_tables_equal(table_view({expect_keys}), result.first->view());
    expect_columns_equal(expect_vals, result.second[0].results[0]->view(), true);
}

auto all_valid() {
    auto all_valid = cudf::test::make_counting_transform_iterator(
        0, [](auto i) { return true; });
    return all_valid;
}

auto all_null() {
    auto all_null = cudf::test::make_counting_transform_iterator(
        0, [](auto i) { return false; });
    return all_null;
}

template <typename V>
struct groupby_sum_test : public cudf::test::BaseFixture {};

TYPED_TEST_CASE(groupby_sum_test, cudf::test::NumericTypes);

TYPED_TEST(groupby_sum_test, basic)
{
    using K = int32_t;
    using V = TypeParam;
    using R = experimental::detail::target_type_t<V, experimental::aggregation::SUM>;

    fixed_width_column_wrapper<K> keys        { 1, 2, 3, 1, 2, 2, 1, 3, 3, 2};
    fixed_width_column_wrapper<V> vals        { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9};

    fixed_width_column_wrapper<K> expect_keys { 1, 2,  3 };
    fixed_width_column_wrapper<R> expect_vals { 9, 19, 17};

    auto agg = cudf::experimental::make_sum_aggregation();
    run_test(keys, vals, expect_keys, expect_vals, std::move(agg));
}

TYPED_TEST(groupby_sum_test, zero_valid_keys)
{
    using K = int32_t;
    using V = TypeParam;
    using R = experimental::detail::target_type_t<V, experimental::aggregation::SUM>;

    fixed_width_column_wrapper<K> keys      ( { 1, 2, 3}, all_null() );
    fixed_width_column_wrapper<V> vals        { 3, 4, 5};

    fixed_width_column_wrapper<K> expect_keys { };
    fixed_width_column_wrapper<R> expect_vals { };

    auto agg = cudf::experimental::make_sum_aggregation();
    run_test(keys, vals, expect_keys, expect_vals, std::move(agg));
}

TYPED_TEST(groupby_sum_test, zero_valid_values)
{
    using K = int32_t;
    using V = TypeParam;
    using R = experimental::detail::target_type_t<V, experimental::aggregation::SUM>;

    fixed_width_column_wrapper<K> keys        { 1, 1, 1};
    fixed_width_column_wrapper<V> vals      ( { 3, 4, 5}, all_null() );

    fixed_width_column_wrapper<K> expect_keys { 1 };
    fixed_width_column_wrapper<R> expect_vals({ 0 }, all_null());

    auto agg = cudf::experimental::make_sum_aggregation();
    run_test(keys, vals, expect_keys, expect_vals, std::move(agg));
}

TYPED_TEST(groupby_sum_test, null_keys_and_values)
{
    using K = int32_t;
    using V = TypeParam;
    using R = experimental::detail::target_type_t<V, experimental::aggregation::SUM>;

    fixed_width_column_wrapper<K> keys(       { 1, 2, 3, 1, 2, 2, 1, 3, 3, 2, 4},
                                              { 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1});
    fixed_width_column_wrapper<V> vals(       { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 4},
                                              { 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0});

                                          //  { 1, 1,     2, 2, 2,   3, 3,    4}
    fixed_width_column_wrapper<K> expect_keys({ 1,        2,         3,       4}, all_valid());
                                          //  { 3, 6,     1, 4, 9,   2, 8,    -}
    fixed_width_column_wrapper<R> expect_vals({ 9,        14,        10,      0},
                                              { 1,         1,         1,      0});

    auto agg = cudf::experimental::make_sum_aggregation();
    run_test(keys, vals, expect_keys, expect_vals, std::move(agg));
}


} // namespace test
} // namespace cudf
